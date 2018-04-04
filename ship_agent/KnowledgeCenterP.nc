#include "game_types.h"
#include "comm.h"

/************************************************************
 * There may be issues with ship ID's and indexes, first I assumed
 * that ship ID is always smaller than MAX_SHIP but then changed my
 * mind and allowed greater ID's. Not sure if everything regarding 
 * this change has been resolved.
 *
 * Edit: I think I resolved most of it now, but I'll leave this notice up.
 *
 * TODO: SHIP_QRMSG is not resolved if update is in progress, but we receive
 * 		 a SHIP_QRMSG message with a ship ID that we don't expect!	
 ************************************************************/

module KnowledgeCenterP
{
	uses interface SysLink;
	uses interface Timer<TMilli> as Timer1;
	uses interface Leds;

	provides interface Init;
	provides interface KnowledgeLink[uint8_t];
}
implementation
{
	//knowledge database about the game and myself
	uint8_t my_location_x = DEFAULT_LOC;
	uint8_t my_location_y = DEFAULT_LOC;
	uint16_t my_load_deadline = DEFAULT_TIME;
	bool my_cargo_loaded = FALSE;

	uint32_t global_load_deadline = DEFAULT_TIME;

	//knowledge database of other ships
	typedef struct skdb {
		bool shipInGame;
		uint8_t shipID;
		uint8_t x_coordinate;
		uint8_t y_coordinate;
		uint32_t ltime; //is this a timestam or just the amount of time left?
		bool isCargoLoaded;
	} skdb;
	skdb ship_kb[MAX_SHIPS];
	uint8_t nShips = 0;

	//stuff needed to handle user commands
	bool updateInProgress = FALSE, SIG_busy = FALSE, newShip = FALSE;
	uint8_t shipsInQue = 0;

	uint8_t returnShipsInGameQueryID = 0;//don't know if 0 can break anything
	uint8_t returnUpdateID = 0;//don't know if 0 can break anything

	task void sendCargoStatusCheck();
	task void sendShipMessages();
	task void getShipInfo();
	void uDone(error_t err);
	uint8_t getIndex(uint8_t id);
	uint8_t getEmptySlot();

	command error_t Init.init()
	{
		uint8_t i=0;
		for(i=0;i<MAX_SHIPS;i++)
		{
			ship_kb[i].shipInGame = FALSE;
			ship_kb[i].shipID = 0;
			ship_kb[i].x_coordinate = DEFAULT_LOC;
			ship_kb[i].y_coordinate = DEFAULT_LOC;
			ship_kb[i].ltime = DEFAULT_TIME;
			ship_kb[i].isCargoLoaded = FALSE;
		}
		return SUCCESS;
	}

	/************************************************************
	 *	Handling new data
	 ************************************************************/

	event void SysLink.responseMsg(queryResponseMsg *rmsg)
	{
		uint8_t index;

		switch(rmsg->messageID)
		{
			case WELCOME_RMSG:
			if(rmsg->x_coordinate != DEFAULT_LOC && rmsg->y_coordinate != DEFAULT_LOC && rmsg->departureT != DEFAULT_TIME)
			{
				if(rmsg->shipID == TOS_NODE_ID)
				{
					my_location_x = rmsg->x_coordinate;
					my_location_y = rmsg->y_coordinate;
					my_load_deadline = rmsg->departureT;
				}
				else 
				{
					index = getIndex(rmsg->shipID);
					if(index >= MAX_SHIPS && index >= 0)
					{
						index = getEmptySlot();
						if(index >= MAX_SHIPS && index >= 0)break; //fall out of switch() because no more room for another ship
					}
					
					ship_kb[index].shipID = rmsg->shipID;
					ship_kb[index].shipInGame = TRUE;
					ship_kb[index].x_coordinate = rmsg->x_coordinate;
					ship_kb[index].y_coordinate = rmsg->y_coordinate;
					ship_kb[index].ltime = (call Timer1.getNow()) + 1000 * rmsg->departureT;
					nShips++;
				}
			}
			break;

			case GTIME_QRMSG:
			if(rmsg->departureT != DEFAULT_TIME)global_load_deadline = (call Timer1.getNow()) + 1000 * rmsg->departureT;
			break;

			case SHIP_QRMSG:
			if(rmsg->shipID == TOS_NODE_ID)break;//ignore me

			index = getIndex(rmsg->shipID);
			if(index >= MAX_SHIPS)//this is a ship we were not waiting for
			{
				index = getEmptySlot();
				if(index >= MAX_SHIPS && index >= 0)
				{
					//this break breaks more than just the switch() loop, and update is not resolved
					//if(updateInProgress)
					break; //fall out of switch() because no more room for another ship
				}
			}
			if(rmsg->x_coordinate != DEFAULT_LOC && rmsg->y_coordinate != DEFAULT_LOC && rmsg->departureT != DEFAULT_TIME)
			{
				ship_kb[index].ltime = (call Timer1.getNow()) + 1000 * rmsg->departureT;
				ship_kb[index].x_coordinate = rmsg->x_coordinate;
				ship_kb[index].y_coordinate = rmsg->y_coordinate;
				if(rmsg->isCargoLoaded != 0)ship_kb[index].isCargoLoaded = TRUE;
				else ship_kb[index].isCargoLoaded = FALSE;
				ship_kb[index].shipInGame = TRUE;
			}
			else ; //here is a nother case for liveloop, getShipInfo will keep asking for ship info
			if(updateInProgress)
			{
				//can this generate a liveleak in some situation???
				//yes if shipID is wrong; I fixed this though.
				post getShipInfo();
			}
			break;

			case AS_QRMSG:
			//this type should not end up here; this type is handled in SystemCommunicationP differently
			break;
			
			default :
			break;
		}
	}

	//this event happens when System sends out a list of all ships in the game
	event void SysLink.ships(uint8_t num_ships, uint8_t sID[])
	{
		uint8_t i, j;

		for(i=0;i<num_ships;i++)
		{
			if(sID[i]!=TOS_NODE_ID)
			{
				if(getIndex(sID[i]) >= MAX_SHIPS)
				{
					j = getEmptySlot();
					if(j < MAX_SHIPS)
					{
						ship_kb[j].shipID = sID[i];
						ship_kb[j].shipInGame = TRUE;
						ship_kb[j].x_coordinate = DEFAULT_LOC;
						ship_kb[j].y_coordinate = DEFAULT_LOC;
						ship_kb[i].ltime = DEFAULT_TIME;
						newShip = TRUE;
						//we stored the new ship in knowledgebase but we don't know
						//its location or departure time. this will be queried later
					}
					else ; //no room for new ship
				}
				else 
				{
					//we already know about this ship
					//but maybe something about the ship has changed?
				}
			}
			else ;//this is me
		}

		//first get cargo status of ships, then get location and departure
		//time info about new ships
		if(updateInProgress)post sendCargoStatusCheck();
	}

	//this event happens when System sends out a list of all ships with cargo
	event void SysLink.cargoLoaded(uint8_t num_ships, uint8_t sID[])
	{
		uint8_t i, j;

		for(i=0;i<num_ships;i++)
		{
			if(sID[i]!=TOS_NODE_ID)
			{
				j = getIndex(sID[i]);
				if(j >= MAX_SHIPS)
				{
					j = getEmptySlot();
					if(j < MAX_SHIPS)
					{
						ship_kb[j].shipID = sID[i];
						ship_kb[j].shipInGame = TRUE;
						ship_kb[j].x_coordinate = DEFAULT_LOC;
						ship_kb[j].y_coordinate = DEFAULT_LOC;
						ship_kb[i].ltime = DEFAULT_TIME;
						ship_kb[j].isCargoLoaded = TRUE;
						//we stored the new ship in knowledgebase but we don't know
						//its location or departure time. this will be queried later
						newShip = TRUE;
					}
					else ; //no room for new ship
				}
				else 
				{
					ship_kb[j].isCargoLoaded = TRUE;
				}
			}
			else my_cargo_loaded = TRUE;//this is me
		}

		if(newShip)post getShipInfo();
		else uDone(SUCCESS);
	}

	uint8_t getIndex(uint8_t id)
	{
		uint8_t k;
		for(k=0;k<MAX_SHIPS;k++)if(ship_kb[k].shipInGame && ship_kb[k].shipID == id)break;
		return k;
	}

	uint8_t getEmptySlot()
	{
		uint8_t k;
		for(k=0;k<MAX_SHIPS;k++)if(!(ship_kb[k].shipInGame))break;
		return k;
	}

	/************************************************************
	 *	Database Queries
	 ************************************************************/

	command error_t KnowledgeLink.getShipsInGame[uint8_t id](uint8_t *sID, uint8_t *len)
	{
		uint8_t i, j=0;
		
		for(i=0;i<MAX_SHIPS;i++)if(ship_kb[i].shipInGame)sID[j++]=ship_kb[i].shipID;
		*len = j;

		return SUCCESS;
	}

	command void KnowledgeLink.cargoWasPlaced[uint8_t id]()
	{
		my_cargo_loaded = TRUE;
	}

	command int16_t KnowledgeLink.getGlobalTimeLeft[uint8_t id]()
	{
		return (int16_t) ((global_load_deadline - call Timer1.getNow()) / 1000);
	}

	command int16_t KnowledgeLink.getMyTimeLeft[uint8_t id]()
	{
		return (int16_t) ((my_load_deadline - call Timer1.getNow()) / 1000);
	}

	command locBundle KnowledgeLink.getMyLocation[uint8_t id]()
	{
		locBundle location;
		location.x_coordinate = my_location_x;
		location.y_coordinate = my_location_y;
		return location;
	}

	command bool KnowledgeLink.isCargoLoaded[uint8_t id]()
	{
		return my_cargo_loaded;
	}

	command locBundle KnowledgeLink.getShipLocation[uint8_t id](uint8_t ship_id)
	{
		locBundle location;
		location.x_coordinate = ship_kb[getIndex(ship_id)].x_coordinate;
		location.y_coordinate = ship_kb[getIndex(ship_id)].y_coordinate;
		return location;
	}

	command int16_t KnowledgeLink.getShipTimeLeft[uint8_t id](uint8_t ship_id)
	{
		return (int16_t) ((ship_kb[getIndex(ship_id)].ltime - call Timer1.getNow()) / 1000);
	}
	
	command bool KnowledgeLink.isCargoLoadedShip[uint8_t id](uint8_t ship_id)
	{
		return ship_kb[getIndex(ship_id)].isCargoLoaded;
	}

	command void KnowledgeLink.cargoWasPlacedHere[uint8_t id](locBundle loc)
	{
		uint8_t i;
		
		for(i=0;i<MAX_SHIPS;i++)if(ship_kb[i].shipInGame)
		{
			if(ship_kb[i].x_coordinate == loc.x_coordinate && ship_kb[i].y_coordinate == loc.y_coordinate)
			{
				ship_kb[i].isCargoLoaded = TRUE;
			}
		}
	}

	/************************************************************
	 *	Database update
	 ************************************************************/

	command error_t KnowledgeLink.updateDatabase[uint8_t id]()
	{
		uint8_t i, j=0;
		error_t err = EBUSY;
		for(i=0;i<MAX_SHIPS;i++)if(ship_kb[i].shipInGame)j++;

		
		//update always includes cargo status check and number of ships in game check
		if(!updateInProgress)
		{
			err = call SysLink.makeAllShipIDQuiery(j);
			if(err == SUCCESS)
			{
				updateInProgress = TRUE;
				returnUpdateID = id;
			}
		}
		return err;
	}

	void uDone(error_t err)
	{
		newShip = FALSE;
		updateInProgress = FALSE;
		signal KnowledgeLink.updateDone[returnUpdateID](err);
	}

	//this task is not used (27.04)
	task void sendShipMessages()
	{
		error_t err;
		err = call SysLink.makeAllShipIDQuiery(55);
		if(err != SUCCESS)
		{
			//update failed
			uDone(FAIL);
		}
		//we need timer here, because response message may never come
	}
	
	task void sendCargoStatusCheck()
	{
		error_t err = call SysLink.makeAllShipCargoQuiery();
		if(err != SUCCESS)
		{
			//update failed
			uDone(FAIL);
		}
		//we need timer here, because response message may never come
	}
	
	task void getShipInfo()
	{
		uint8_t i;
		error_t err;

		for(i=0;i<MAX_SHIPS;i++)
		{
			if(ship_kb[i].shipInGame && ship_kb[i].x_coordinate == DEFAULT_LOC)
			{
				err = call SysLink.makeShipQuiery(ship_kb[i].shipID);
				if(err != SUCCESS)uDone(FAIL);
			}
		}
		uDone(SUCCESS);
	}

	command uint8_t KnowledgeLink.getID[uint8_t id](uint8_t index)
	{
		if(ship_kb[index].shipInGame)return ship_kb[index].shipID;
		else return 0;//zero is an invalid moteID (shipID) in tinyOS
	}
	
	command uint8_t KnowledgeLink.getIndex[uint8_t id](uint8_t senderID)
	{
		return getIndex(senderID);
	}

	event void Timer1.fired(){}
	default event void KnowledgeLink.updateDone[uint8_t id](error_t err){call Leds.led0On();}
}
