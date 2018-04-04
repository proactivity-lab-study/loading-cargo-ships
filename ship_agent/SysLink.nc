#include "comm.h"
interface SysLink
{
	command error_t makeShipQuiery(uint8_t shipID);
	command error_t makeAllShipIDQuiery(uint8_t len);
	command error_t makeAllShipCargoQuiery();
	command error_t makeGlobalTimeQuiery();

	event void responseMsg(queryResponseMsg *rmsg);
	event void ships(uint8_t num_ships, uint8_t sID[]);
	event void cargoLoaded(uint8_t num_ships, uint8_t sID[]);
}