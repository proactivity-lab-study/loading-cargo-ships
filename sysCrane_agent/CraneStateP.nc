module CraneStateP
{
	uses interface CraneLink;
	uses interface KnowledgeLink;
	uses interface Leds;
	uses interface Random;
	uses interface ParameterInit<uint16_t> as Seed;
	uses interface Timer<TMilli>;
	uses interface BufferOp<uint8_t> as SerialLink;

	provides interface StdControl;
}
implementation
{
	#define MAXLEN_SERIAL_BUF 20


	uint8_t sCmd[MAX_SHIPS], serialBuf[MAXLEN_SERIAL_BUF];

	uint8_t craneX, craneY;
	bool cargoInCurrentLoc = FALSE, locked = FALSE;
	uint8_t winningcmd;

	bool isCargoHere();
	void doCommand();
	void resolveCmd();	
	uint8_t randomNumber(uint8_t rndL, uint8_t rndH);
	void sendPositionToSerial();

	task void sendLocation();
	task void sendSerial();
	
	command error_t StdControl.start()
	{
		uint8_t i;
		uint16_t seeder;

		//initialise buffer
		for(i=0;i<MAX_SHIPS;i++)sCmd[i] = 0;

		//give seed to random
		seeder = (call Timer.getNow()) & 65535UL;
		call Seed.init(seeder);

		//get crane start location
		craneY = randomNumber(GRID_LOWER_BOUND, GRID_UPPER_BOUND+1);
		craneX = randomNumber(GRID_LOWER_BOUND, GRID_UPPER_BOUND+1);

		//start periodic timer		
		call Timer.startPeriodic(CRANE_UPDATE_INTERVAL);

		return SUCCESS;
	}

	command error_t StdControl.stop(){return FAIL;}

	event void CraneLink.newCommand(uint8_t senderID, uint8_t cmd)
	{
		uint8_t index;
		if(!locked)
		{
			if(cmd == CM_CURRENT_LOCATION)
			{
				post sendLocation();
			}
			else if(cmd > 0 && cmd < CM_CURRENT_LOCATION)
			{
				index = call KnowledgeLink.getIndex(senderID);
				if(index < MAX_SHIPS)sCmd[index] = cmd;
				else ;//ship not in game, command dropped
			}
			else if(cmd == CM_NOTHING_TO_DO) ; //this command shouldn't be sent, but no harm done, just ignore
			else ;//invalid command, do nothing
		}
	}

	event void Timer.fired()
	{
		if(!locked)
		{
			locked = TRUE;
			resolveCmd();
		}
	}

	task void sendLocation()
	{
		//there may be a case where radio message is sent
		//but serial message fails and locked is not returned to FALSE
		//which means that ships think that crane accepts new commands
		//but actually crane doesn't accept commands

		error_t err = call CraneLink.newPosition(craneX, craneY, isCargoHere());
		if(err != SUCCESS)
		{
			post sendLocation();
		}
	}

	bool isCargoHere()
	{
		if(cargoInCurrentLoc)return TRUE;
		else if(call KnowledgeLink.isCargoHere(craneX, craneY))return TRUE;
		else return FALSE;
	}

	void resolveCmd()
	{
		uint8_t votes[6], i, rnd, mcount, max;
		bool atLeastOne = FALSE;

		for(i=0;i<6;i++)votes[i] = 0;

		//find most popular command
		for(i=0;i<MAX_SHIPS;i++)
		{
			if(sCmd[i] != 0)
			{
				votes[sCmd[i]]++;
				atLeastOne = TRUE;
			}
		}

		//if no commands from ships don't move
		if(!atLeastOne)
		{
			winningcmd = 0;
			doCommand();
			return;
		}

		//get max
		max = votes[1];
		for(i=2;i<6;i++)
		{
			if(votes[i]>max)max = votes[i];
		}
		//check if there are more than one max and mark these buffer locations, clear other locations
		mcount = 0;
		for(i=1;i<6;i++)
		{
			if(votes[i] == max){votes[i] = 1;mcount++;}
			else votes[i] = 0;
		}
		if(mcount>1)
		{
			//get random modulo mcount
			rnd = randomNumber(1, mcount+1);

			for(i=1;i<6;i++)if(votes[i] == 1)
			{
				rnd--;
				if(rnd == 0){winningcmd = i;break;}//winning command
			}
		}
		else for(i=1;i<6;i++)if(votes[i] == 1){winningcmd = i;break;}
		doCommand();
	}

	void doCommand()
	{
		cargoInCurrentLoc = FALSE;
		switch(winningcmd)
		{
			case CM_UP: if(craneY<GRID_UPPER_BOUND)craneY++;
			break;
			case CM_DOWN: if(craneY>GRID_LOWER_BOUND)craneY--;
			break;
			case CM_LEFT: if(craneX>GRID_LOWER_BOUND)craneX--;
			break;
			case CM_RIGHT: if(craneX<GRID_UPPER_BOUND)craneX++;
			break;
			case CM_PLACE_CARGO: cargoInCurrentLoc = TRUE;
			break;
			default: //zero ends up here
			break;
		}
		if(cargoInCurrentLoc)call KnowledgeLink.cargoPlacedTo(craneX, craneY);

		//send notification of new position
		sendPositionToSerial();
		post sendLocation();
	}

	void sendPositionToSerial()
	{
		uint8_t len, i, id;
		error_t err;

		len = 1;
		
		serialBuf[len++] = SERIAL_CRANE_LOCMSG;//messageID
		serialBuf[len++] = craneX;
		serialBuf[len++] = craneY;
		if(cargoInCurrentLoc)serialBuf[len++] = 1;
		else serialBuf[len++] = 0;

		//give popular command points and clear buffer
		for(i=0;i<MAX_SHIPS;i++)
		{
			if(winningcmd != 0 && sCmd[i] == winningcmd)
			{
				//give points
				id = call KnowledgeLink.getID(i);
				if(id != 0)serialBuf[len++] = id;
			}
			sCmd[i] = 0;//clear previous commands
		}
		serialBuf[0] = len;

		err = call SerialLink.doIt(serialBuf, len, FALSE);
		if(err != SUCCESS)post sendSerial();
		else locked = FALSE;
	}

	task void sendSerial()
	{
		sendPositionToSerial();
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

	event void KnowledgeLink.getCraneLoc(uint8_t *x, uint8_t *y)
	{
		*x = craneX;
		*y = craneY;
	}

	event void SerialLink.done(uint8_t * buf, uint8_t *buf2, error_t err){}
}