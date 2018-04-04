interface SysLink2
{
	command error_t registerNewShip(uint8_t shipID);
	command error_t getShipInfo(uint8_t shipID, uint8_t *x, uint8_t *y, uint16_t *dt, bool *isCL);
	command uint16_t getGlobalTime();
	command error_t getAllShips(uint8_t buf[], uint8_t *len);
	command error_t getAllCargo(uint8_t buf[], uint8_t *len);
}