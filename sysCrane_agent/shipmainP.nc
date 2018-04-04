module shipmainP
{
    uses interface Boot;
    uses interface Leds;
    uses interface SplitControl as AMControl;
    uses interface SplitControl as SerialControl;
    uses interface StdControl as CraneStart;
    uses interface StdControl as StartGame;
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
            call SerialControl.start();
        }
        else call AMControl.start();
    }

    event void AMControl.stopDone(error_t err){}

    event void SerialControl.startDone(error_t err)
    {
        if (err == SUCCESS)
        {
            call StartGame.start();
            call CraneStart.start();
        }
        else call AMControl.start();
    }

    event void SerialControl.stopDone(error_t err){}
}
