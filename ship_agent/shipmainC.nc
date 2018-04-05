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

    //------- SHIPMAINP
    shipmainP.Boot -> MainC;
    shipmainP.Leds -> LedsC;
    shipmainP.AMControl -> ActiveMessageC;

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
    SystemCommunicationP.SendWelcomeMsg <- shipmainP.SendWelcomeMsg;

    //------- KNOWLEDGE BASE
    components KnowledgeCenterP;
    components new TimerMilliC() as Timer1;
    MainC.SoftwareInit -> KnowledgeCenterP;
    KnowledgeCenterP.Timer1 -> Timer1;
    KnowledgeCenterP.Leds -> LedsC;
    SystemCommunicationP.SysLink <- KnowledgeCenterP;

    //------- CRANE STRATEGY
    components CraneControlP;
    components new TimerMilliC() as Timer2;
    components new TimerMilliC() as Timer3;
    components new KDBUserC(unique(UQ_KNOWLEDGE_DB_USER)) as KDB_CraneControl;
    CraneControlP.CraneLink -> CraneCommunicationP;
    CraneControlP.KnowledgeLink -> KDB_CraneControl;
    CraneControlP.Leds -> LedsC;
    CraneControlP.Timer -> Timer2;
    CraneControlP.Timer2 -> Timer3;


    //------- SHIP-SHIP STRATEGY
    components ShipControlP;
    components new KDBUserC(unique(UQ_KNOWLEDGE_DB_USER)) as KDB_ShipControl;
    ShipControlP.KnowledgeLink -> KDB_ShipControl;
    ShipControlP.Leds -> LedsC;
    ShipControlP.StdControl <- shipmainP.Ship;
}


  
  