module ShipControlP
{
	uses interface KnowledgeLink;
	uses interface Leds;
	provides interface StdControl;
}
implementation
{
	event void KnowledgeLink.updateDone(error_t err)
	{

	}
	command error_t StdControl.start()
	{
		return SUCCESS;
	}

	command error_t StdControl.stop(){return FAIL;}

}