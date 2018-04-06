module shipmainP
{
    uses interface Boot;
    uses interface Leds;
    uses interface SplitControl as AMControl;
    uses interface StdControl as Ship;
    uses interface StdControl as SendWelcomeMsg;
}
implementation
{
    event void Boot.booted()
    {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err)
    {
        if (err == SUCCESS)
        {
            //ship agent must start by sending a welcome message
            call SendWelcomeMsg.start();

            //start the strategy motor
            call Ship.start();           
        }
        else call AMControl.start();
    }

    event void AMControl.stopDone(error_t err){}
}
