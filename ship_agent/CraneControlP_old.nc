#include "game_types.h"
#include "comm.h"

/************************************************************
 * TODO: There is no strategy for what happens after the ship receives
 * its cargo.
 ************************************************************/

module CraneControlP
{
	uses interface CraneLink;
	uses interface KnowledgeLink;
	uses interface Leds;
	uses interface Timer<TMilli>;
	

	provides interface StrategyImpl;
}
implementation
{
	enum
	{
		SS_DESTINATION,
		SS_PARROT,
		SS_POPULAR
	};

	#define STILL_TIME_TO_WAIT 150
	#define WAIT_SOME_TIME 50

	uint32_t lastCraneEvent = 0;
	uint8_t ship_cmd[MAX_SHIPS];
	uint8_t ship_ID[MAX_SHIPS];

	uint8_t cCraneX = DEFAULT_LOC, cCraneY = DEFAULT_LOC;
	bool wasCargoPlaced = FALSE, doUpdate = TRUE;
	bool Xfirst = TRUE;//which coordinate to use first, X is default
	uint8_t strategy;
	locBundle dest_loc;
	uint8_t parrot_shipID;
	bool alwaysPlaceCargo = TRUE; //always send 'place cargo' command when crane is on top of a ship

	void goToDestination(locBundle loc);
	void parrotShip(uint8_t sID);
	void selectPopular();

	//void strategyToMe();
	//void strategyNearestToCrane();
	//void strategyAfterCargo();

	uint16_t distToCrane(uint8_t x, uint8_t y);
	//uint16_t distToMe(uint8_t x, uint8_t y);
	//uint16_t distAtoB(uint8_t Ax, uint8_t Ay, uint8_t Bx, uint8_t By);
	uint8_t selectCommandYFirst(locBundle loc);
	uint8_t selectCommandXFirst(locBundle loc);
	uint8_t selectCommand(locBundle loc);


	/************************************************************
	 * Implementation of strategies.
	 ************************************************************/

	//send commands that take the crane to this loc
	command void StrategyImpl.goToDestination(locBundle loc)
	{
		strategy = SS_DESTINATION;
		dest_loc = loc;
	}

	//send the same command that 'shipID' is currently sending
	command void StrategyImpl.parrotShip(uint8_t shipID)
	{
		//parroting overides the 'always place cargo' tactic
		strategy = SS_PARROT;
		parrot_shipID = shipID;
	}

	//send the command, that is currently most popular
	command void StrategyImpl.sendPopular()
	{
		//popular choice overides the 'always place cargo' tactic
		strategy = SS_POPULAR;
	}
	
	//when going to some destination, first go along X coordinate, then Y
	command void StrategyImpl.useXFirst()
	{
		Xfirst = TRUE;
	}
	//when going to some destination, first go along Y coordinate, then X
	command void StrategyImpl.useYFirst()
	{
		Xfirst = FALSE;
	}
	//when crane is above some ship, always send place cargo command
	command void StrategyImpl.alwaysPlaceCargo(bool alwaysPlace)
	{
		alwaysPlaceCargo = alwaysPlace;
	}

	event void Timer.fired()
	{
		switch(strategy)
		{
			case SS_DESTINATION:
			goToDestination(dest_loc);
			break;

			case SS_PARROT:
			//parroting overides the 'always place cargo' tactic
			parrotShip(parrot_shipID);
			break;

			case SS_POPULAR:
			//popular choice overides the 'always place cargo' tactic
			selectPopular();
			break;

			default:
			break;
		}
		//if(call KnowledgeLink.isCargoLoaded())strategyAfterCargo();
		//else 
		//strategyNearestToCrane();
		//strategyNearestToMe();
		//strategyToMe();
	}

	//void strategyAfterCargo()
	//{
	//	strategyToMe();
		//strategyNearestToMe();
		//strategyNearestToCrane();
	//}

	void goToDestination(locBundle loc)
	{
		uint8_t cmnd = 0;
		
		cmnd = selectCommand(loc);

		if(cmnd != CM_NOTHING_TO_DO)
		{
			call CraneLink.send_command(cmnd);
			call Leds.led1Toggle();
		}
		else ; //we have completed the strategy, maybe notify ShipControl?
	}

	void parrotShip(uint8_t sID)
	{
		uint8_t cmd;
		uint32_t now;
		uint8_t index = call KnowledgeLink.getIndex(sID);

		if(index >= 0 && index <MAX_SHIPS)
		{
			cmd = ship_cmd[index];
			if(cmd != 0)call CraneLink.send_command(cmd);
			else
			{
				//the ship to parrot has not sent a command yet (or at all)
				//if there is time to wait, lets wait
				now = call Timer.getNow();
				if((now - lastCraneEvent) < (CRANE_UPDATE_INTERVAL - STILL_TIME_TO_WAIT))
				{
					call Timer.startOneShot(lastCraneEvent + CRANE_UPDATE_INTERVAL - now - STILL_TIME_TO_WAIT);
				}
				else 
				{
					//apparently the ship to parrot hasn't sent a command, neither will we

					//todo: notify ShipControl
				}
			}
		}
	}

	void selectPopular()
	{
		uint8_t i, n;
		uint8_t cmd[7];
		uint32_t now;

		//empty the buffer
		for(i=1;i<7;i++)cmd[i] = 0;

		for(i=0;i<MAX_SHIPS;i++)
		{
			switch(ship_cmd[i])
			{
				case CM_UP ://1
				cmd[1]++;
				break;

				case CM_DOWN ://2
				cmd[2]++;
				break;

				case CM_LEFT ://3
				cmd[3]++;
				break;

				case CM_RIGHT ://4
				cmd[4]++;
				break;

				case CM_PLACE_CARGO ://5
				cmd[5]++;
				break;

				case CM_CURRENT_LOCATION ://6
				cmd[6]++;
				break;

				default ://0 && 7
				break;
			}
		}

		//this favors the first most popular choice, if there are more than one most popular commands at the moment
		n=0;
		cmd[0] = CM_NOTHING_TO_DO;
		for(i=1;i<7;i++)if(n < cmd[i])
		{
			n = cmd[i];
			cmd[0] = i;//using the 0 index memory area for this, because it is available anyway
		}
		
		if(cmd[0] != CM_NOTHING_TO_DO)call CraneLink.send_command(cmd[0]);
		else
		{
			//there were no commands at all
			//if there is time to wait, lets wait
			now = call Timer.getNow();
			if((now - lastCraneEvent) < (CRANE_UPDATE_INTERVAL - STILL_TIME_TO_WAIT))
			{
				call Timer.startOneShot(lastCraneEvent + CRANE_UPDATE_INTERVAL - now - STILL_TIME_TO_WAIT);
			}
			else 
			{
				//apparently the ship to parrot hasn't sent a command, neither will we

				//todo: notify ShipControl
			}
		}
	}

	uint8_t selectCommand(locBundle destLoc)
	{
		uint8_t ships[MAX_SHIPS], len, i;
		locBundle loc;

		//first check if cargo was placed in the last round, if not, maybe we need to
		if(!wasCargoPlaced)
		{
			//there is no cargo in this place, is there a ship here and do we need to place cargo?
			if(alwaysPlaceCargo)
			{
				call KnowledgeLink.getShipsInGame(ships, &len);

				if(len > 0 && len <= MAX_SHIPS)
				{
					for(i=0;i<len;i++)
					{
						loc = call KnowledgeLink.getShipLocation(ships[i]);
						//if there is a ship here, then only reasonable command is place cargo
						if(distToCrane(loc.x_coordinate, loc.y_coordinate) == 0)return CM_PLACE_CARGO;//found ship in this location
					}
				}
				else ; //no more ships in game besides me

				//if I reach here, then there are no ships besides me in the game
				//or there are more ships but no one is at the current crane location
				//therefor just continue with the strategy
			}
			else ; //don't care about cargo placement unless it serves my strategy
		}
		else ; //cargo was placed by the crane in the last round, so no need to place it again this round

		if(Xfirst)return selectCommandXFirst(destLoc);
		else return selectCommandYFirst(destLoc);
	}

	uint8_t selectCommandXFirst(locBundle loc)
	{
		if(loc.y_coordinate > cCraneY)return CM_UP;
		else if(loc.y_coordinate < cCraneY)return CM_DOWN;
		else ;

		if(loc.x_coordinate > cCraneX)return CM_RIGHT;
		else if(loc.x_coordinate < cCraneX)return CM_LEFT;
		else ;

		//if we get here, then the crane is at the desired location 'loc'
		//check if there isn't cargo here, then issue place, else return with 'do nothing'
		//this ensures that we only place cargo to a ship only once
		if(wasCargoPlaced)return CM_NOTHING_TO_DO;
		else return CM_PLACE_CARGO;
	}

	uint8_t selectCommandYFirst(locBundle loc)
	{
		if(loc.x_coordinate > cCraneX)return CM_RIGHT;
		else if(loc.x_coordinate < cCraneX)return CM_LEFT;
		else ;

		if(loc.y_coordinate > cCraneY)return CM_UP;
		else if(loc.y_coordinate < cCraneY)return CM_DOWN;
		else ;

		//if we get here, then the crane is at the desired location 'loc'
		//check if there isn't cargo here, then issue 'place cargo', else return with 'do nothing'
		//this ensures that we only place cargo to a ship only once
		if(wasCargoPlaced)return CM_NOTHING_TO_DO;
		else return CM_PLACE_CARGO;
	}

	uint16_t distToCrane(uint8_t x, uint8_t y)
	{
		return abs(cCraneX - x) + abs(cCraneY - y);
	}

	/************************************************************
	 * Communication with crane.
	 ************************************************************/

	event void CraneLink.craneLocation(uint8_t location_x, uint8_t location_y, bool cargoPlaced)
	{
		uint8_t i, k=0;
		locBundle loc;

		lastCraneEvent = call Timer.getNow();

		cCraneX = location_x;
		cCraneY = location_y;
		wasCargoPlaced = cargoPlaced;

		//if cargo was placed, check if we need to update our knowledge base
		if(wasCargoPlaced)
		{
			//check for me
			loc = call KnowledgeLink.getMyLocation();
			if(loc.x_coordinate == location_x && loc.y_coordinate == location_y && cargoPlaced)
			{
				call KnowledgeLink.cargoWasPlaced();
			}
			else //check for everybody else
			{
				if(call KnowledgeLink.getShipsInGame(ship_ID, &k) == SUCCESS)for(i=0;i<k;i++)
				{
					loc = call KnowledgeLink.getShipLocation(ship_ID[k]);
					if(loc.x_coordinate == location_x && loc.y_coordinate == location_y)
					{
						call KnowledgeLink.cargoWasPlacedHere(loc);
					}
				}
			}
		}

		for(i=0;i<MAX_SHIPS;i++)ship_cmd[i] = 0;
		call Leds.led0Toggle();
		call Timer.startOneShot(500);
	}

	event void CraneLink.craneCommandFrom(uint8_t senderID, uint8_t cmd)
	{
		//this indexing could break baddly if sync is lost between this buffer and the buffers in KnowledgeCenter
		uint8_t index = call KnowledgeLink.getIndex(senderID);
		if(index >= 0 && index <MAX_SHIPS)ship_cmd[index] = cmd;

		//new crane commands from other ships cause reevaluation of our crane command when using strategy 'popular' or 'parrot'
		if(strategy == SS_POPULAR && strategy == SS_PARROT)call Timer.startOneShot(WAIT_SOME_TIME);
	}
}