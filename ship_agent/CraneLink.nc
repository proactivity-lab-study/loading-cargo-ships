interface CraneLink
{
	command error_t send_command(uint8_t cmd);
	event void craneLocation(uint8_t location_x, uint8_t location_y, bool cargoPlaced);
	event void craneCommandFrom(uint8_t shipID, uint8_t cmd);
}