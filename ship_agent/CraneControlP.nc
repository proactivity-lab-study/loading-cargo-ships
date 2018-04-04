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
	uses interface Timer<TMilli> as Timer2;
}
implementation
{
	uint32_t counter = 0;
	uint8_t ship_cmd[MAX_SHIPS];

	uint8_t cCraneX = DEFAULT_LOC, cCraneY = DEFAULT_LOC;
	bool wasCargoPlaced = FALSE, doUpdate = TRUE;

	void strategyToMe();
	void strategyNearestToCrane();
	void strategyAfterCargo();

	uint16_t distToCrane(uint8_t x, uint8_t y);
	uint16_t distToMe(uint8_t x, uint8_t y);
	uint16_t distAtoB(uint8_t Ax, uint8_t Ay, uint8_t Bx, uint8_t By);
	uint8_t selectCommandYFirst(locBundle loc);
	uint8_t selectCommandXFirst(locBundle loc);
	uint8_t selectCommand(locBundle loc);

	event void CraneLink.craneLocation(uint8_t location_x, uint8_t location_y, bool cargoPlaced)
	{
		uint8_t i;
		locBundle loc;

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

			}
		}

		for(i=0;i<MAX_SHIPS;i++)ship_cmd[i] = 0;
		call Leds.led0Toggle();
		call Timer.startOneShot(500);

		//doing an update is a costly process, it involves sending several update 
		//request messages to system and waiting for responces.
		//however an update is sometimes necessary, because if a ship doesn't know
		//that another ship has entered the game or that another ship has received 
		//cargo, it will use a faulty strategy.
		//the knowledge center component of ships source code is designed to 
		//automatically detect new ships and cargo placement, but as in any real 
		//world application things can go wrong (i.e. message not received) and 
		//that is why occasional update requests are a good idea
		if(doUpdate)
		{
			doUpdate = FALSE;
			call Timer2.startOneShot(30000); //every 30 seconds
		}
	}

	event void CraneLink.craneCommandFrom(uint8_t senderID, uint8_t cmd)
	{
		uint8_t index = call KnowledgeLink.getIndex(senderID);
		if(index >= 0 && index <MAX_SHIPS)ship_cmd[index] = cmd;
	}

	event void KnowledgeLink.updateDone(error_t err)
	{
		call Leds.led2Toggle();
	}

	event void Timer.fired()
	{
		if(call KnowledgeLink.isCargoLoaded())strategyAfterCargo();
		else 
		//strategyNearestToCrane();
		//strategyNearestToMe();
		strategyToMe();
	}

	event void Timer2.fired()
	{
		call KnowledgeLink.updateDatabase();

		//should be in event updateDone, but update may fail
		//no failsafe for update at the moment
		doUpdate = TRUE;
	}

	void strategyAfterCargo()
	{
		strategyToMe();
		//strategyNearestToMe();
		//strategyNearestToCrane();
	}

	void strategyToMe()
	{
		uint8_t cmnd = 0;
		locBundle myLoc = call KnowledgeLink.getMyLocation();

		cmnd = selectCommand(myLoc);

		if(cmnd != CM_NOTHING_TO_DO)
		{
			call CraneLink.send_command(cmnd);
			call Leds.led1Toggle();
		}
	}

	void strategyNearestToCrane()
	{
		uint8_t ships[MAX_SHIPS], len, cmnd, nearest = 0, i;
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
			return;
		}

		if(nearest != 0)
		{
			cmnd = selectCommand(loc);
			if(cmnd != CM_NOTHING_TO_DO)
			{
				call CraneLink.send_command(cmnd);
				call Leds.led1Toggle();
			}
			else ;//TODO:what happens now??
		}
	}

	void strategyNearestToMe()
	{
		uint8_t ships[MAX_SHIPS], len, cmnd, nearest=0, i;
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
			return;
		}

		if(nearest != 0)
		{
			cmnd = selectCommand(loc);
			if(cmnd != CM_NOTHING_TO_DO)
			{
				call CraneLink.send_command(cmnd);
				call Leds.led1Toggle();
			}
			else ;//TODO:what happens now??
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

	uint8_t selectCommand(locBundle destLoc)
	{
		uint8_t ships[MAX_SHIPS], len, i;
		locBundle loc;

		//first check if there is a ship in current crane location
		if(!wasCargoPlaced)
		{
			//there is no cargo in this place, is there a ship here?
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
		else ; //there is cargo here, continue with strategy

		//return selectCommandYFirst(destLoc);
		return selectCommandXFirst(destLoc);
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
		//check if there isn't cargo here, then issue place, else return with 'do nothing'
		//this ensures that we only place cargo to a ship only once
		if(wasCargoPlaced)return CM_NOTHING_TO_DO;
		else return CM_PLACE_CARGO;
	}

}