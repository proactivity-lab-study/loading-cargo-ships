module ShipControlP
{
	uses interface KnowledgeLink;
	uses interface Leds;
	uses interface StrategyImpl;
	uses interface Timer<TMilli>;
	uses interface Timer<TMilli> as Timer2;
	provides interface StdControl;
}
implementation
{
	#define DATABASE_UPDATE_INTERVAL 30000UL //about 30 seconds

	uint8_t shipToParrot;

	void strategyToMe();
	void strategyNearestToCrane();
	void strategyNearestToMe();
	void strategyFollowShip();
	void strategyPopularChoise();

	uint16_t distToCrane(uint8_t x, uint8_t y);
	uint16_t distToMe(uint8_t x, uint8_t y);
	uint16_t distAtoB(uint8_t Ax, uint8_t Ay, uint8_t Bx, uint8_t By);

	//crane location is needed here
	uint8_t cCraneX = DEFAULT_LOC, cCraneY = DEFAULT_LOC;

	command error_t StdControl.start()
	{
		//select a strategy

		call Timer2.startPeriodic(5000);
		//strategyNearestToCrane();
		//strategyNearestToMe();
		//strategyFollowShip();
		//strategyPopularChoise();

		//select tactics

		call StrategyImpl.useXFirst();
		//call StrategyImpl.useYFirst();
		call StrategyImpl.alwaysPlaceCargo(TRUE);

		//start periodic KnowledgeCenter updates
		call Timer.startOneShot(DATABASE_UPDATE_INTERVAL);

		return SUCCESS;
	}

	command error_t StdControl.stop(){return FAIL;}

	event void Timer2.fired()
	{
		strategyToMe();
	}
	
	void strategyToMe()
	{
		call StrategyImpl.goToDestination(call KnowledgeLink.getMyLocation());
	}

	void strategyFollowShip()
	{
		//this will only work if the ship to parrot actually exists
		//it will not work (it will do nothing) with TOS_NODE_ID
		shipToParrot = TOS_NODE_ID;
		call StrategyImpl.parrotShip(shipToParrot);
	}

	void strategyPopularChoise()
	{
		call StrategyImpl.sendPopular();
	}


	void strategyNearestToCrane()
	{
		//not finished!
		uint8_t ships[MAX_SHIPS], len, nearest = 0, i;
		locBundle loc, loc2;
		uint16_t dist = 65535UL, dist2;

		call KnowledgeLink.getShipsInGame(ships, &len);

		if(len > 0 && len <= MAX_SHIPS)
		{
			for(i=0;i<len;i++)//find first ship in list without cargo
			{
				if(!call KnowledgeLink.isCargoLoadedShip(ships[i]))
				{
					nearest = ships[i];
					loc = call KnowledgeLink.getShipLocation(nearest);
					dist = distToCrane(loc.x_coordinate, loc.y_coordinate);
					break;
				}
			}
			
			for(i++;i<len;i++)//continue from where previous loop stopped
			{
				if(!call KnowledgeLink.isCargoLoadedShip(ships[i]))
				{
					loc2 = call KnowledgeLink.getShipLocation(ships[i]);
					dist2 = distToCrane(loc2.x_coordinate, loc2.y_coordinate);
					if(dist2 < dist)
					{
						loc = loc2;
						dist = dist2;
						nearest = ships[i];
					}
				}
			}

			if(!call KnowledgeLink.isCargoLoaded())//I don't have cargo yet
			{
				//maybe I am closest to crane?
				loc2 = call KnowledgeLink.getMyLocation();
				dist2 = distToCrane(loc2.x_coordinate, loc2.y_coordinate);
				if(dist2 < dist)
				{
					loc = loc2;
					dist = dist2;
					nearest = TOS_NODE_ID;
				}
			}
		}
		else //I am only ship
		{
			strategyToMe();
		}

		if(nearest != 0)
		{
			//send location to crane control
			call StrategyImpl.goToDestination(loc);
		}
	}

	void strategyNearestToMe()
	{
		//not finished!
		uint8_t ships[MAX_SHIPS], len, nearest=0, i;
		locBundle loc, loc2;
		uint16_t dist, dist2;

		call KnowledgeLink.getShipsInGame(ships, &len);

		if(len > 0 && len <= MAX_SHIPS)
		{
			for(i=0;i<len;i++)//find first ship in list without cargo
			{
				if(!call KnowledgeLink.isCargoLoadedShip(ships[i]))
				{
					nearest = ships[i];
					loc = call KnowledgeLink.getShipLocation(nearest);
					dist = distToCrane(loc.x_coordinate, loc.y_coordinate);
					break;
				}
			}

			for(i++;i<len;i++)//continue from where previous loop stopped
			{
				loc2 = call KnowledgeLink.getShipLocation(ships[i]);
				dist2 = distToMe(loc2.x_coordinate, loc2.y_coordinate);
				if(dist2 < dist)
				{
					loc = loc2;
					dist = dist2;
					nearest = ships[i];
				}
			}

			if(nearest == 0)//everybody has cargo already, what about me?
			{
				if(!call KnowledgeLink.isCargoLoaded())
				{
					nearest = TOS_NODE_ID;
					loc = call KnowledgeLink.getMyLocation();
				}
			}
		}
		else //I am only ship
		{
			strategyToMe();
		}

		if(nearest != 0)
		{
			//send location to crane control
			call StrategyImpl.goToDestination(loc);
		}
	}
	
	uint16_t distToCrane(uint8_t x, uint8_t y)
	{
		return abs(cCraneX - x) + abs(cCraneY - y);
	}

	uint16_t distToMe(uint8_t x, uint8_t y)
	{
		locBundle myLoc = call KnowledgeLink.getMyLocation();
		return abs(myLoc.x_coordinate - x) + abs(myLoc.y_coordinate - y);
	}

	uint16_t distAtoB(uint8_t Ax, uint8_t Ay, uint8_t Bx, uint8_t By)
	{
		return abs(Ax - Bx) + abs(Ay - By);
	}



	/************************************************************
	 * Doing database update. 
	 ************************************************************/

	event void KnowledgeLink.updateDone(error_t err)
	{
		call Timer.startOneShot(DATABASE_UPDATE_INTERVAL);
		call Leds.led2Toggle();
	}

	

	event void Timer.fired()
	{
		call KnowledgeLink.updateDatabase();
	}

}