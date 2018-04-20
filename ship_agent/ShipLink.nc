interface ShipLink
{
	command error_t targetProposal(uint8_t ship_id);
	command error_t moveProposal(uint8_t move);
	event void targetApproval(bool approved);
	//event void craneCommandFrom(uint8_t shipID, uint8_t cmd);
}