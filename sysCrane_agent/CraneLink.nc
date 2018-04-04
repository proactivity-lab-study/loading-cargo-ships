interface CraneLink
{
	command error_t newPosition(uint8_t xloc, uint8_t yloc, bool cargoPlaced);
	
	event void newCommand(uint8_t senderID, uint8_t cmd);
}