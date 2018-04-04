#include "comm.h"

configuration shipmainC
{

}
implementation
{
    #define UQ_KNOWLEDGE_DB_USER "knowledge_db_user"
    
    components MainC;
    components LedsC;
    components shipmainP;
    components ActiveMessageC;
    components FlushBufferToSerialC;

    //------- SHIPMAINP
    shipmainP.Boot -> MainC;
    shipmainP.Leds -> LedsC;
    shipmainP.AMControl -> ActiveMessageC;
    shipmainP.SerialControl -> FlushBufferToSerialC;

    //------- CRANE SEND-RECEIVE
    components new AMSenderC(AM_CRANECOMMUNICATION) as CSenderC;
    components new AMReceiverC(AM_CRANECOMMUNICATION) as CReceiverC;
    components CraneCommunicationP;
    CraneCommunicationP.Packet -> CSenderC;
    CraneCommunicationP.AMSend -> CSenderC;
    CraneCommunicationP.Receive -> CReceiverC;

    //------- SYSTEM SEND-RECEIVE
    components new AMSenderC(AM_SYSTEMCOMMUNICATION) as SSenderC;
    components new AMReceiverC(AM_SYSTEMCOMMUNICATION) as SReceiverC;
    components SystemCommunicationP;
    SystemCommunicationP.Packet -> SSenderC;
    SystemCommunicationP.AMSend -> SSenderC;
    SystemCommunicationP.Receive -> SReceiverC;
    SystemCommunicationP.Leds -> LedsC;
    

    //------- KNOWLEDGE BASE
    components ShipStateP;
    components new TimerMilliC() as Timer1;
    components RandomC;
    MainC.SoftwareInit -> ShipStateP;
    ShipStateP.Timer1 -> Timer1;
    ShipStateP.Leds -> LedsC;
    SystemCommunicationP.SysLink2 -> ShipStateP;
    ShipStateP.Random -> RandomC;
    ShipStateP.Seed -> RandomC;
    ShipStateP.SerialLink -> FlushBufferToSerialC.FlushUint8t;
    ShipStateP.StdControl <- shipmainP.StartGame;

    //------- CRANE STRATEGY
    components CraneStateP;
    components new TimerMilliC() as Timer2;
    CraneStateP.Random -> RandomC;
    CraneStateP.Seed -> RandomC;
    CraneStateP.CraneLink -> CraneCommunicationP;
    CraneStateP.Leds -> LedsC;
    CraneStateP.Timer -> Timer2;
    CraneStateP.KnowledgeLink -> ShipStateP;
    CraneStateP.StdControl <- shipmainP.CraneStart;
    CraneStateP.SerialLink -> FlushBufferToSerialC.FlushUint8t_2;
}


  
  
