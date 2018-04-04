generic configuration KDBUserC(uint8_t id)
{
	provides interface KnowledgeLink;
}
implementation
{
	components KnowledgeCenterP;
	KnowledgeLink = KnowledgeCenterP.KnowledgeLink[id];
}