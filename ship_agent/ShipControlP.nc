module ShipControlP
{
	uses interface KnowledgeLink;
	uses interface Leds;
	uses interface StrategyImpl;
	uses interface Timer<TMilli>;
	provides interface StdControl;
}
implementation
{
	#define DATABASE_UPDATE_INTERVAL 30000UL //about 30 seconds

	void myStrategy();
	

	command error_t StdControl.start()
	{
		//start a strategy
		myStrategy();

		//start periodic KnowledgeCenter updates
		call Timer.startOneShot(DATABASE_UPDATE_INTERVAL);
		return SUCCESS;
	}
	command error_t StdControl.stop(){return FAIL;}

	void myStrategy()
	{
		//no strategy yet so calling empty function
		call StrategyImpl.empty();
	}

	



	/************************************************************
	 * Do knowledgebase updates.
	 ************************************************************/

	event void Timer.fired()
	{
		call KnowledgeLink.updateDatabase();
	}

	event void KnowledgeLink.updateDone(error_t err)
	{
		call Timer.startOneShot(DATABASE_UPDATE_INTERVAL);
	}

}