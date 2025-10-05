#include "virtualmap/virtualmap_core.as"
#include "scp079/scp079.as"

void OnInitialize() // Initialize when script loads. Don't use WORLD functions there.
{
	InitializeVirtualMap();
	InitializeSCP079();
}

void OnWorldLoaded()
{
	OnVirtualMapWorldLoaded();
}
