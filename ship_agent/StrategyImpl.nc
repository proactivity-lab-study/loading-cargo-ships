interface StrategyImpl
{
	//strategies

	//send commands that take the crane to this loc
	command void goToDestination(locBundle loc);
	//send the same command that 'shipID' is currently sending
	command void parrotShip(uint8_t shipID);
	//send the command, that is currently most popular
	command void sendPopular();
	
	//general tactics

	//when going to some destination, first go along X coordinate, then Y
	command void useXFirst();//default is X
	//when going to some destination, first go along Y coordinate, then X
	command void useYFirst();//default is X
	//when crane is above some ship, always send place cargo command
	command void alwaysPlaceCargo(bool alwaysPlace);

	command locBundle getCraneLocation();
}