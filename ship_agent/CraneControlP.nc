#include "game_types.h"
#include "comm.h"

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

	uint8_t cCraneX = DEFAULT_LOC, cCraneY = DEFAULT_LOC;
	bool wasCargoPlaced = FALSE;

	/************************************************************
	 * Implementation of strategies.
	 ************************************************************/

	//send commands that take the crane to this loc
	command void StrategyImpl.empty()
	{
		//what will our first strategy be?
	}

	event void Timer.fired()
	{
		
	}


	/************************************************************
	 * Communication with crane.
	 ************************************************************/

	event void CraneLink.craneLocation(uint8_t location_x, uint8_t location_y, bool cargoPlaced)
	{
		cCraneX = location_x;
		cCraneY = location_y;
		wasCargoPlaced = cargoPlaced;

		call Leds.led0Toggle();
	}

	event void CraneLink.craneCommandFrom(uint8_t senderID, uint8_t cmd)
	{
		//just now ship with ID 'senderID' sent the command 'cmd' to crane
		//what are we going to do about it?
	}

	event void KnowledgeLink.updateDone(error_t err)
	{
		//ignore this
	}
}