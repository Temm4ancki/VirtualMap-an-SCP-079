#include "../include/uerm.as"
#include "scp079_base.as"

const float DOOR_DETECT_RANGE = 12.0;
const float DOOR_THRESHOLD = 0.9;

namespace SCP079Doors
{
    array<GUIElement> doorHighlights(MAX_PLAYERS + 1);
    array<Door> targetedDoors(MAX_PLAYERS + 1);
    array<GUIElement> doorBeams(MAX_PLAYERS + 1);
    
    void Initialize()
    {
        for(int i = 0; i <= MAX_PLAYERS; i++)
        {
            doorHighlights[i] = NULL;
            targetedDoors[i] = NULL;
            doorBeams[i] = NULL;
        }
    }
    
    void UpdateDoorHighlighting(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= doorHighlights.size()) return;
        
        Door lookedDoor = GetDoorPlayerIsLookingAt(player);
        
        if(targetedDoors[idx] != lookedDoor)
        {
            RemoveDoorHighlighting(player);
            
            if(lookedDoor != NULL)
            {
                CreateDoorHighlighting(player, lookedDoor);
            }
            
            targetedDoors[idx] = lookedDoor;
        }
    }
    
    Door GetDoorPlayerIsLookingAt(Player player)
    {
        if(player == NULL) return NULL;
        
        Entity playerEnt = player.GetEntity();
        if(playerEnt == NULL) return NULL;
        
        float px = playerEnt.PositionX();
        float py = playerEnt.PositionY();
        float pz = playerEnt.PositionZ();
        float yaw = playerEnt.Yaw();
        float pitch = playerEnt.Pitch();
        
        float yawRad = yaw * 3.14159265359 / 180.0;
        float pitchRad = pitch * 3.14159265359 / 180.0;
        
        float lookX = -sin(yawRad) * cos(pitchRad);
        float lookY = -sin(pitchRad);
        float lookZ = cos(yawRad) * cos(pitchRad);
        
        float mag = sqrt(lookX * lookX + lookY * lookY + lookZ * lookZ);
        if(mag > 0.0001)
        {
            lookX /= mag;
            lookY /= mag;
            lookZ /= mag;
        }
        
        Door closestDoor = NULL;
        float closestDist = DOOR_DETECT_RANGE + 1.0;
        
        for(int i = 0; i < MAX_DOORS; i++)
        {
            Door door = world.GetDoor(i);
            if(door == NULL) continue;
            
            int doorType = door.GetDoorType();
            if(doorType == OFFICE_DOOR || doorType == FENCE_DOOR || doorType == WOODEN_DOOR) continue;
            
            Entity doorEnt = door.GetEntity();
            if(doorEnt == NULL) continue;
            
            float dx = doorEnt.PositionX();
            float dy = doorEnt.PositionY();
            float dz = doorEnt.PositionZ();
            
            float toDoorX = dx - px;
            float toDoorY = dy - py;
            float toDoorZ = dz - pz;
            float doorDist = sqrt(toDoorX * toDoorX + toDoorY * toDoorY + toDoorZ * toDoorZ);
            
            if(doorDist > DOOR_DETECT_RANGE || doorDist < 0.1) continue;
            
            float projLen = (toDoorX * lookX + toDoorY * lookY + toDoorZ * lookZ);
            
            if(projLen < 0.5) continue;
            
            float projX = lookX * projLen;
            float projY = lookY * projLen;
            float projZ = lookZ * projLen;
            
            float perpX = toDoorX - projX;
            float perpY = toDoorY - projY;
            float perpZ = toDoorZ - projZ;
            
            float horizPerp = sqrt(perpX * perpX + perpZ * perpZ);
            float vertPerp = abs(perpY);
            
            float pitchFactor = abs(pitch) / 90.0;
            float horizThreshold = DOOR_THRESHOLD * (1.0 + pitchFactor * 2.0);
            float vertThreshold = DOOR_THRESHOLD * (3.0 + pitchFactor * 3.0);
            
            if(horizPerp <= horizThreshold && vertPerp <= vertThreshold)
            {
                if(projLen < closestDist)
                {
                    closestDist = projLen;
                    closestDoor = door;
                }
            }
        }
        
        return closestDoor;
    }
    
    void CreateDoorHighlighting(Player player, Door door)
    {
        if(player == NULL || door == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= doorHighlights.size()) return;
        
        Entity doorEnt = door.GetEntity();
        if(doorEnt == NULL) return;
        
        CreateDoorBeam(player, door);
    }
    
    void CreateDoorBeam(Player player, Door door)
    {
        if(player == NULL || door == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= doorBeams.size()) return;
        
        GUIElement beam = graphics.CreateImage(player, "GFX\\HUD\\hand_symbol(1).png", 0.49, 0.488, 0.02, 0.032, true);
        if(beam != NULL)
        {
            beam.SetColor(255, 255, 255);
        }
        
        doorBeams[idx] = beam;
    }
    
    void RemoveDoorHighlighting(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= doorHighlights.size()) return;
        
        if(doorHighlights[idx] != NULL)
        {
            doorHighlights[idx].Remove();
            doorHighlights[idx] = NULL;
        }
        
        if(doorBeams[idx] != NULL)
        {
            doorBeams[idx].Remove();
            doorBeams[idx] = NULL;
        }
    }
    
    string GetDoorTypeName(int doorType)
    {
        switch(doorType)
        {
            case DEFAULT_DOOR: return "Standard Door";
            case ELEVATOR_DOOR: return "Elevator Door";
            case HEAVY_DOOR: return "Heavy Door";
            case BIG_DOOR: return "Large Door";
            case OFFICE_DOOR: return "Office Door";
            case WOODEN_DOOR: return "Wooden Door";
            case FENCE_DOOR: return "Fence Door";
            case ONE_SIDED_DOOR: return "One-Sided Door";
            case SCP_914_DOOR: return "SCP-914 Door";
            default: return "Unknown Door";
        }
    }
    
    string GetDoorAccessName(int doorAccess)
    {
        switch(doorAccess)
        {
            case NONE: return "No Access Required";
            case DOOR_KEYCARD: return "Keycard Required";
            case DOOR_DNA: return "DNA Scanner";
            case DOOR_KEYPAD: return "Keypad";
            case DOOR_OWF: return "One Way Function";
            case DOOR_ELEVATOR: return "Elevator Control";
            default: return "Unknown Access";
        }
    }
    
    void UseDoorPlayerIsLookingAt(Player player)
    {
        if(player == NULL) return;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= targetedDoors.size()) return;
        
        Door targetDoor = targetedDoors[idx];
        if(targetDoor == NULL)
        {
            SCP079Base::ShowMessage(player, "No door in sight", 2.0);
            return;
        }
        
        if(targetDoor.GetLockState() != 0)
        {
            SCP079Base::ShowMessage(player, "Door is locked and cannot be operated", 3.0);
            return;
        }
        
        int doorAccess = targetDoor.GetDoorAccess();
        if(doorAccess == DOOR_KEYCARD || doorAccess == DOOR_DNA || doorAccess == DOOR_KEYPAD)
        {
            string accessType = GetDoorAccessName(doorAccess);
            SCP079Base::ShowMessage(player, "Bypassing " + accessType + "...", 2.0);
        }
        
        bool wasOpen = targetDoor.IsOpened();
        targetDoor.Use();
        
        string action = wasOpen ? "closed" : "opened";
        string doorType = GetDoorTypeName(targetDoor.GetDoorType());
        SCP079Base::ShowMessage(player, "Door " + action + ": " + doorType, 3.0);
    }
    
    void OnPlayerKeyAction(Player player, int newKeys, int prevKeys)
    {
        if(player == NULL || !SCP079Base::IsSCP079Player(player)) return;
        
        if(IsKeyPressed(KEY_F, newKeys, prevKeys))
        {
            UseDoorPlayerIsLookingAt(player);
        }
    }
    
    void OnPlayerDisconnect(Player player)
    {
        if(player == NULL) return;
        
        RemoveDoorHighlighting(player);
        
        int idx = player.GetIndex();
        if(idx >= 0 && idx < targetedDoors.size())
        {
            targetedDoors[idx] = NULL;
        }
    }
    
    Door GetPlayerLookedAtDoor(Player player)
    {
        if(player == NULL) return NULL;
        
        int idx = player.GetIndex();
        if(idx < 0 || idx >= targetedDoors.size()) return NULL;
        
        return targetedDoors[idx];
    }
}
