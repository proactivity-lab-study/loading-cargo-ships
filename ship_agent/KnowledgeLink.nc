#include "comm.h"

interface KnowledgeLink
{
	//global time info and general game info
	command int16_t getGlobalTimeLeft();
	command error_t getShipsInGame(uint8_t *buf, uint8_t *len);
	command void cargoWasPlacedHere(locBundle loc);
	
	//commands about my info
	command int16_t getMyTimeLeft();
	command locBundle getMyLocation();
	command bool isCargoLoaded();
	command void cargoWasPlaced();

	//commands about ship info
	command int16_t getShipTimeLeft(uint8_t ship_id);
	command locBundle getShipLocation(uint8_t ship_id);
	command bool isCargoLoadedShip(uint8_t ship_id);

	//not sure if these are used by anyone
	command uint8_t getIndex(uint8_t senderID);
	command uint8_t getID(uint8_t index);

	//this command is split-phase
	command error_t updateDatabase();
	event void updateDone(error_t err);
}
	