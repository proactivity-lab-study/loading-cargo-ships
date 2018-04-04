#include "game_types.h"
#include "comm.h"

/*
 * TODO: When cargo is placed on a ship, we need to send a radio message so everybody knows, 
 * that cargo was placed!
 *
 */


module ShipStateP
{
	uses interface Timer<TMilli> as Timer1;
	uses interface Leds;
	uses interface Random;
	uses interface ParameterInit<uint16_t> as Seed;
	uses interface BufferOp<uint8_t> as SerialLink;

	provides interface Init;
	provides interface SysLink2;
	provides interface KnowledgeLink;
	provides interface StdControl;
}
implementation
{
	#define DURATION_OF_GAME 600L //seconds
	#define MAXLEN_SERIAL_BUF 10

	uint32_t global_load_deadline = DEFAULT_TIME;

	//knowledge database of other ships
	typedef struct skdb {
		bool shipInGame;
		uint8_t shipID;
		uint8_t x_coordinate;
		uint8_t y_coordinate;
		uint32_t ltime;
		bool isCargoLoaded;
	} skdb;

	skdb ship_kb[MAX_SHIPS];
	uint8_t nShips = 0;
	uint8_t serialBuf[MAXLEN_SERIAL_BUF];

	uint8_t getIndex(uint8_t id);
	uint8_t getEmptySlot();
	uint8_t randomNumber(uint8_t rndL, uint8_t rndH);
	uint16_t randomNumber2(uint16_t rndL, uint16_t rndH);
	void sendShipInfoToSerial(uint8_t index);

	bool retrySerialNewShip = FALSE;
	uint8_t retrySerialIndex;
	uint8_t counter = 0;

	error_t makeCoordinates(uint8_t index);
	error_t makeDTime(uint8_t index);

	task void sendSerialGlobalTime();
	task void sendSerialCargoLoaded();
	task void retrySerial();

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

	command error_t StdControl.start()
	{
		global_load_deadline = call Timer1.getNow() + (DURATION_OF_GAME * 1000);

		//send global time over serial
		return post sendSerialGlobalTime();
	}

	command error_t StdControl.stop(){}

	/************************************************************
	 *	Handling new data
	 ************************************************************/

	command error_t SysLink2.registerNewShip(uint8_t shipID)
	{
		uint8_t index = getIndex(shipID);
		uint16_t seeder = (call Timer1.getNow()) & 65535UL;

		if(index >= MAX_SHIPS)index = getEmptySlot();
		
		if(index < MAX_SHIPS)
		{
			call Seed.init(seeder);//this actually only needs to be done once, but no harm doing it more
			makeCoordinates(index);
			makeDTime(index);
			ship_kb[index].isCargoLoaded = FALSE;
			ship_kb[index].shipID = shipID;
			ship_kb[index].shipInGame = TRUE;
			if(retrySerialNewShip)call Leds.led2On();//now we are fucked, last new ship has not been successfully sent over serial, but we already have a new one
			else sendShipInfoToSerial(index);
			nShips++;
			return SUCCESS;
		}
		else return FAIL;
	}

	error_t makeCoordinates(uint8_t index)
	{
		uint8_t k;
		uint8_t xloc, yloc;

		xloc = randomNumber(GRID_LOWER_BOUND, GRID_UPPER_BOUND+1);
		yloc = randomNumber(GRID_LOWER_BOUND, GRID_UPPER_BOUND+1);

		//check that no other ship is in this location
		for(k=0;k<MAX_SHIPS;k++)
		{
			if(ship_kb[k].shipInGame)
			{
				if(ship_kb[k].x_coordinate == xloc && ship_kb[k].y_coordinate == yloc)
				{
					return FAIL;
				}
			}
		}
		ship_kb[index].x_coordinate = xloc;
		ship_kb[index].y_coordinate = yloc;
		return SUCCESS;		
	}

	error_t makeDTime(uint8_t index)
	{
		uint16_t lower, upper;

		//these need to be set somehow in relation to ship location
		//TODO: check that deadline does not exceed global deadline

		lower = 1;
		upper = DURATION_OF_GAME;
		ship_kb[index].ltime = call Timer1.getNow() + ((uint32_t)randomNumber2(lower, upper) * 1000);
		return SUCCESS;
	}

	/************************************************************
	 *	Database Queries
	 ************************************************************/
	
	command error_t SysLink2.getShipInfo(uint8_t shipID, uint8_t *x, uint8_t *y, uint16_t *dt, bool *isCL)
	{
		uint8_t i = getIndex(shipID);


		if(i < MAX_SHIPS && ship_kb[i].shipInGame)
		{
			*x = ship_kb[i].x_coordinate;
			*y = ship_kb[i].y_coordinate;
			*dt = ship_kb[i].ltime;
			*isCL = ship_kb[i].isCargoLoaded;
			return SUCCESS;
		}
		else return FAIL;
	}

	command uint16_t SysLink2.getGlobalTime()
	{
		return (uint16_t)((global_load_deadline - call Timer1.getNow()) / 1000);
	}

	command error_t SysLink2.getAllShips(uint8_t buf[], uint8_t *len)
	{
		uint8_t i, u=0;
		for(i=0;i<MAX_SHIPS;i++)if(ship_kb[i].shipInGame)
		{
			buf[u]=ship_kb[i].shipID;
			u++;
		}
		*len = u;
		return SUCCESS;
	}

	command error_t SysLink2.getAllCargo(uint8_t buf[], uint8_t *len)
	{
		uint8_t i, u=0;
		for(i=0;i<MAX_SHIPS;i++)if(ship_kb[i].shipInGame)if(ship_kb[i].isCargoLoaded)
		{
			buf[u]=ship_kb[i].shipID;
			u++;
		}
		*len = u;
		return SUCCESS;
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

	uint8_t randomNumber(uint8_t rndL, uint8_t rndH)//random number between rndL and (rndH - 1)
	{
		//something I once wrote, don't remember, what happens here, hoping it is still good
		uint8_t msec = 0;
		uint32_t seed = call Random.rand32();
		
		if(rndL < rndH)
		{
			if(seed != 0)
			{
				while(seed < rndH)
				{
					seed *= 10;
				}
			}
			msec = seed % rndH;
			if(msec < rndL)
			{
				seed = msec / rndL;
				msec = (uint8_t) (rndL + (rndH - rndL) * seed);
			}
		}
		return msec;
	}

	uint16_t randomNumber2(uint16_t rndL, uint16_t rndH)//random number between rndL and (rndH - 1)
	{
		//something I once wrote, don't remember, what happens here, hoping it is still good
		uint16_t msec = 0;
		uint32_t seed = call Random.rand32();
		
		if(rndL < rndH)
		{
			if(seed != 0)
			{
				while(seed < rndH)
				{
					seed *= 10;
				}
			}
			msec = seed % rndH;
			if(msec < rndL)
			{
				seed = msec / rndL;
				msec = (uint16_t) (rndL + (rndH - rndL) * seed);
			}
		}
		return msec;
	}

	void sendShipInfoToSerial(uint8_t index)
	{
		error_t err;

		//is the struct computed into a string the way I think?
		newShipSerialMsg* smsg = (newShipSerialMsg*)serialBuf;

		smsg->length = sizeof(newShipSerialMsg);
		smsg->messageID = SERIAL_NEWSHIP_MSG;
		smsg->shipID = ship_kb[index].shipID;
		smsg->xLoc = ship_kb[index].x_coordinate;
		smsg->yLoc = ship_kb[index].y_coordinate;
		smsg->dTime =(uint16_t)((ship_kb[index].ltime - call Timer1.getNow())/1000);

		err = call SerialLink.doIt(serialBuf, sizeof(newShipSerialMsg), FALSE);
		if(err != SUCCESS)
		{
			retrySerialNewShip = TRUE;
			retrySerialIndex = index;
			post retrySerial();
		}
		else call Leds.led2On();
	}

	task void sendSerialGlobalTime()
	{
		error_t err;

		//is the struct computed into a string the way I think?
		gTimeSerialMsg* smsg = (gTimeSerialMsg*)serialBuf;

		smsg->length = sizeof(gTimeSerialMsg);
		smsg->messageID = SERIAL_GLOBALTIME_MSG;
		smsg->gTime = (uint16_t)((global_load_deadline - call Timer1.getNow())/1000);
		
		err = call SerialLink.doIt(serialBuf, sizeof(gTimeSerialMsg), FALSE);
		if(err != SUCCESS)post sendSerialGlobalTime();
	}

	task void retrySerial()
	{
		if(retrySerialNewShip)sendShipInfoToSerial(retrySerialIndex);
	}

	event void Timer1.fired(){}

	command bool KnowledgeLink.isCargoHere(uint8_t craneX, uint8_t craneY)
	{
		uint8_t i;

		for(i=0;i<MAX_SHIPS;i++)if(ship_kb[i].shipInGame)
		{
			if(ship_kb[i].x_coordinate == craneX && ship_kb[i].y_coordinate == craneY)
			{
				return ship_kb[i].isCargoLoaded;
			}
		}
		return FALSE;
	}
	
	command void KnowledgeLink.cargoPlacedTo(uint8_t craneX, uint8_t craneY)
	{
		uint8_t i;

		for(i=0;i<MAX_SHIPS;i++)if(ship_kb[i].shipInGame)
		{
			if(ship_kb[i].x_coordinate == craneX && ship_kb[i].y_coordinate == craneY)
			{
				ship_kb[i].isCargoLoaded = TRUE;
				post sendSerialCargoLoaded();
				//TODO send info to radio also!!
			}
		}
	}

	task void sendSerialCargoLoaded()
	{
		//TODO
		//not doing it at first, maybe later
	}

	event void SerialLink.done(uint8_t* dbuf, uint8_t* rbuf, error_t err)
	{
		if(err != SUCCESS)call Leds.led2On();
	}

	command uint8_t KnowledgeLink.getIndex(uint8_t senderID)
	{
		return getIndex(senderID);
	}

	command uint8_t KnowledgeLink.getID(uint8_t index)
	{
		if(ship_kb[index].shipInGame)return ship_kb[index].shipID;
		else return 0;//zero is an invalid moteID (shipID) in tinyOS
	}
}
