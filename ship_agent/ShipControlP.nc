module ShipControlP
{
	uses interface KnowledgeLink;
	uses interface Leds;
	uses interface StrategyImpl;
	uses interface Timer<TMilli> as KBUpdateTimer;
	uses interface Timer<TMilli> as StratEvalTimer;
	uses interface Timer<TMilli> as ProposalTimeout;
	uses interface ShipLink;
	provides interface StdControl;
}
implementation
{
	enum
	{
		STRAT_TO_ME,
		STRAT_TO_TARGET,
		STRAT_PARROT_SHIP
	};

	#define DATABASE_UPDATE_INTERVAL 30000UL //about 30 seconds
	#define SHIP_PROPOSAL_TIMEOUT 1000UL
	uint8_t singame[MAX_SHIPS], num_ship = 0;
	uint8_t proposedStrategy;
	locBundle crane_loc, target_loc;
	locBundle my_loc;

	bool first = TRUE, second = FALSE, third = FALSE;

	void goalFunction();
	uint16_t distance(locBundle a, locBundle b);
	

	command error_t StdControl.start()
	{
		//general tactics
		//call StrategyImpl.useYFirst();//default is X
		//when crane is above some ship, always send place cargo command
		call StrategyImpl.alwaysPlaceCargo(TRUE);

		//start a strategy
		call StratEvalTimer.startOneShot(2000);
		//call StratEvalTimer.startPeriodic(2000);

		//start periodic KnowledgeCenter updates
		call KBUpdateTimer.startOneShot(DATABASE_UPDATE_INTERVAL);
		return SUCCESS;
	}
	command error_t StdControl.stop(){return FAIL;}

	void doStrategy(uint8_t strat)
	{
		switch(strat)
		{
			case STRAT_TO_ME :
			call StrategyImpl.goToDestination(call KnowledgeLink.getMyLocation());
			break;

			case STRAT_TO_TARGET :

			call StrategyImpl.goToDestination(target_loc);
			break;

			default :
			break;
		}

		//set timer for reevaluation of strategy in the future
		call StratEvalTimer.startOneShot(20000);//~ 20 seconds
	}

	void send_proposal(uint8_t p_id)
	{
		call ShipLink.targetProposal(p_id, p_id);
		//call ShipLink.moveProposal(8, p_id);
		//proposedStrategy = STRAT_TO_ME;
		
		call ProposalTimeout.startOneShot(SHIP_PROPOSAL_TIMEOUT);
	}

	void goalFunction()
	{
		uint8_t i, partner_id = 0, strat;
		uint16_t partner_dist = 0xffff, dist;
		locBundle n_loc;

		strat = STRAT_TO_ME;//my defaut strategy
		
		//find closest ship to me and make proposal to it
		call KnowledgeLink.getShipsInGame(singame, &num_ship);
		my_loc = call StrategyImpl.getCraneLocation();
		//my_loc = call KnowledgeLink.getMyLocation();

		for(i=0;i<num_ship;i++)
		{
			n_loc = call KnowledgeLink.getShipLocation(singame[i]);
			dist = distance(my_loc, n_loc);
			if(dist < partner_dist)
			{
				partner_dist = dist;
				partner_id = singame[i];
				target_loc = n_loc;
				proposedStrategy = STRAT_TO_TARGET;
			}
		}

		if(partner_dist == 0xffff);
		else
		{
			if(partner_id != 0)send_proposal(partner_id);
		}
		doStrategy(strat);
	}

	event void StratEvalTimer.fired()
	{
		goalFunction();//decide my strategy for now
		//doStrategy(STRAT_TO_ME);
	}

	event void ProposalTimeout.fired()
	{
		doStrategy(STRAT_TO_ME);
	}

	/************************************************************
	 * Ship communication events.
	 ************************************************************/

	event void ShipLink.responseFrom(uint8_t shipID, bool approved)
	{
		call ProposalTimeout.stop();
		if(approved)
		{
			doStrategy(proposedStrategy);
		}
		else
		{
			doStrategy(STRAT_TO_ME);
		}
	}

	event void ShipLink.targetProposalFrom(uint8_t ship_id, uint8_t target_id)
	{
		//my strategy with incoming proposals is that I will only accept the 
		//proposal that proposes the ship that is closest to the crane
		//also I will always changes my current strategy for this one

		locBundle n_loc;
		uint16_t dist, dist2=0xffff;//max distance for dist2 in case there are no other ships
		uint8_t i;

		crane_loc = call StrategyImpl.getCraneLocation();
		n_loc = call KnowledgeLink.getShipLocation(target_id);

		//find distance to crane for proposed ship
		dist = distance(crane_loc, n_loc);

		//get all other ships and check if anyone is closer than proposed target
		call KnowledgeLink.getShipsInGame(singame, &num_ship);

		for(i=0;i<num_ship;i++)
		{
			target_loc = call KnowledgeLink.getShipLocation(singame[i]);
			dist2 = distance(crane_loc, target_loc);
			if(dist2 < dist)
			{
				//this ship is closer than proposed target ship, break loop and decline proposal
				break;
			}
		}

		if(dist2<dist)call ShipLink.sendResponse(ship_id, FALSE);
		else 
		{
			call ShipLink.sendResponse(ship_id, TRUE);
			target_loc = n_loc;
			doStrategy(proposedStrategy);
		}
	}

	event void ShipLink.moveProposalFrom(uint8_t ship_id, uint8_t cmd)
	{
		//no strategy for this type of proposal yet
		call ShipLink.sendResponse(ship_id,FALSE);
	}

	/************************************************************
	 * Do knowledgebase updates.
	 ************************************************************/

	event void KBUpdateTimer.fired()
	{
		call KnowledgeLink.updateDatabase();
	}

	event void KnowledgeLink.updateDone(error_t err)
	{
		call KBUpdateTimer.startOneShot(DATABASE_UPDATE_INTERVAL);
	}

	/************************************************************
	 * Helper functions
	 ************************************************************/

	uint16_t distance(locBundle a, locBundle b)
	{
		return abs(a.x_coordinate - b.x_coordinate) + abs(a.y_coordinate - b.y_coordinate);
	}

}
