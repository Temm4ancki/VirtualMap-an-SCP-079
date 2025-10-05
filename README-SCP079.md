# SCP-079 System

A complete surveillance and facility control system for SCP-079 gameplay in SCP: Breach. Provides camera viewing, door control, facility mapping, and player detection with dynamic map generation support.

## Features

- **Camera System**: Place and view custom cameras throughout the facility
- **Door Control**: Open/close doors remotely with access bypass
- **Facility Map**: Interactive map with camera locations and player detection
- **Player Tracking**: Real-time detection of personnel in camera view (with delay)
- **Dynamic Maps**: Full support for procedurally generated facility layouts
- **HUD System**: Custom surveillance interface with status information

## Installation

### 1. File Structure

Place these files in `scripts/Breach/scp079/`:
- `scp079.as` - Main entry point and initialization
- `scp079_base.as` - Core player state management
- `scp079_hud.as` - HUD rendering and display
- `scp079_cameras.as` - Camera placement and viewing system
- `scp079_doors.as` - Door detection and control
- `scp079_map.as` - Facility map integration

### 2. Dependencies

Required systems:
- VirtualMap system (`scripts/Breach/virtualmap/`)
- UERM includes (`scripts/Breach/include/uerm.as`)

### 3. Integration with Breach Gamemode

#### Main Gamemode File (`breach.as`)

Add the includes and initialization:

```angelscript
#include "virtualmap/virtualmap_core.as"
#include "scp079/scp079.as"

void OnInitialize()
{
    InitializeVirtualMap();
    InitializeSCP079();
}

void OnWorldLoaded()
{
    OnVirtualMapWorldLoaded();
}
```

#### Player Management (`players.as`)

Include the SCP-079 system at the top of the file:

```angelscript
#include "scp079/scp079.as"
```

In the `SetPlayerRole()` function, add SCP-079 role handling in the switch statement:

```angelscript
switch(playerInfo.pClass.roleid) 
{
    case 0:
    {
        break;
    }
    case ROLE_SCP_173:
    {
        chat.SendPlayer(p, "&colr[0 255 0]" + "----------------------------");
        chat.SendPlayer(p, "Ваши способности:");
        chat.SendPlayer(p, "&colr[0 255 255]" + "Кнопка X" + "&colr[255 255 255]" + " - Отключает свет на большом расстоянии");
        chat.SendPlayer(p, "&colr[0 255 0]" + "----------------------------");
        break;
    }
    case ROLE_SCP_079:
    {
        SetupSCP079ForPlayer(p);
        break;
    }
}
```

In the `NullPlayerStats()` function, add cleanup for SCP-079:

```angelscript
void NullPlayerStats(Player p)
{
    info_Player@ playerInfo = GetPlayerInfo(p);
    Role@ prevRole = playerInfo.pClass;
    
    if(@prevRole != null && prevRole.roleid == ROLE_SCP_079)
    {
        SCP079::StopCameraForPlayer(p);
        SCP079::OnPlayerDisconnect(p);
    }
    
    // ... rest of the function
}
```

In the `PlayerCallbacks::OnChat()` function, add command processing:

```angelscript
bool OnChat(Player player, string message)
{
    // ... existing chat code ...
    
    if(message.substr(0, 1) == "/") 
    {
        if(ProcessSCP079Command(player, message))
        {
            return false;
        }
        
        // ... rest of command processing ...
    }
    
    return false;
}
```

### 4. Role Setup

The SCP-079 role is already defined in `roles.as`. In the `Roles::Initialize()` function, the role is created like this:

```angelscript
Role@ scp079 = RoleROLE_SCP_079, "SCP-079", ATEGORY_ANOMALY, PlayerModelCLASS_D_MODEL), Color(200, , 0), "Наблюдай за омплексом. Используй карту M). Помогай или мешай ыжившим. Жди 45 секунд чтобы вигаться.",
{
	Spawnpoint(vector3(140.2, -10894.2, 1558.2), 0.0, 0.0, world.GetRoomByIdentifier(r_cont1_079))
}, {}, true, 0.0, 1000, 0.0, rue);

Add(scp079);  // Add to roles array
```

### 5. Player Setup

The role system automatically handles player setup. When a player is assigned the SCP-079 role, the system calls `SetupSCP079ForPlayer(player)` after a 1-second delay.

**Automatic setup flow:**
1. Player is assigned ROLE_SCP_079 during role assignment
2. Player spawns at SCP-079 containment chamber
3. `SetupSCP079ForPlayer()` is called automatically
4. SCP-079 systems initialize (camera, HUD, map)

**Manual setup (if needed):**
```angelscript
SetupSCP079ForPlayer(player);
```

**Check if player is SCP-079:**
```angelscript
info_Player@ playerInfo = GetPlayerInfo(player);
if(@playerInfo != null && @playerInfo.pClass != null)
{
    if(playerInfo.pClass.roleid == ROLE_SCP_079)
    {
        // Player is SCP-079
    }
}

// Or use the helper function:
if(SCP079::IsSCP079Player(player))
{
    // Player is SCP-079
}
```

## Camera System

### Placing Cameras

Cameras are stored in `scp079/scp079_cameras.txt` with room-relative coordinates for map generation compatibility.

**In-game placement:**
```
/addcam
/addcamera
```

Position yourself where you want the camera, then use the command. The camera will be saved with your current position and rotation.

**Manual file format:**
```
# localX,localY,localZ,pitch,yaw,roomIdentifier,roomName
0.500,1.200,0.300,-15.000,0.000,3,cont1_173
-0.800,1.500,0.200,-20.000,90.000,43,cont1_079
```

Coordinates are room-relative (scaled by 0.1) to work with any map generation.

### Camera File Management

The system automatically:
- Creates `scp079/` directory if missing
- Loads cameras on world load
- Saves cameras when added/removed
- Converts coordinates for current map layout

### Camera Controls

- **N Key**: Switch to next camera in room
- **M Key**: Open facility map to select room
- **F Key**: Interact with door in view

## Door Control

### Door Detection

The system detects doors in the player's view using:
- Ray-casting from camera position
- Distance threshold: 12.0 units
- Automatic highlighting when looking at doors
- Excludes office, fence, and wooden doors

### Door Interaction

Press **F** to interact with the targeted door:
- Opens closed doors
- Closes open doors
- Bypasses keycard/DNA/keypad requirements
- Cannot operate locked doors (lock state != 0)

### Door Types Supported

- Standard doors
- Heavy doors
- Elevator doors
- Big doors
- One-sided doors
- SCP-914 doors

## Facility Map

### Map Features

- Interactive room selection
- Camera availability indicators
- Current viewing room highlight
- Zone-based color coding:
  - Yellow: Light Containment Zone
  - Red: Heavy Containment Zone
  - Blue: Entrance Zone
  - Orange: Checkpoints

### Map Controls

- **M Key**: Toggle map on/off
- **Click Room**: Jump to camera in that room
- Rooms without cameras show warning message

### Map Integration

The map uses VirtualMap API for:
- Dynamic room layout
- Real-time player positions
- Room connectivity
- Zone classification

## HUD System

### Display Elements

**Main Info Display** (top-left):
```
CAMERA: SCP-173 CAM #1
STATUS: Camera Active
DETECTED (2):
• D-9341 [Class-D Personnel]
• MTF Unit [MTF Operative]
```

**Controls Display** (bottom-left):
```
M: Map | N: Next Cam | F: Use Door
```

### Status Messages

Temporary messages appear for:
- Camera switching
- Door operations
- System errors
- Access attempts

### Player Detection

Detection includes:
- Player count in current room
- Player names and roles
- SCP entities (shows SCP designation only)
- 3-second delay for gameplay balance

## API Reference

### Core Functions

#### `void SetupSCP079ForPlayer(Player player)`
Initialize SCP-079 for a player.

```angelscript
SetupSCP079ForPlayer(player);
```

#### `bool ProcessSCP079Command(Player player, const string& in message)`
Process SCP-079 commands (returns true if handled).

```angelscript
void OnPlayerChat(Player player, string message)
{
    if(ProcessSCP079Command(player, message))
        return;
}
```

### SCP079 Namespace

#### `bool IsSCP079Player(Player player)`
Check if player is SCP-079.

```angelscript
if(SCP079::IsSCP079Player(player))
{
    // Player is SCP-079
}
```

#### `bool IsPlayerInCameraMode(Player player)`
Check if player is viewing a camera.

```angelscript
if(SCP079::IsPlayerInCameraMode(player))
{
    // Player is in camera view
}
```

#### `void StartCameraInRoom(Player player, Room targetRoom)`
Start camera view in specific room.

```angelscript
Room room = world.GetRoomByIndex(roomIndex);
if(room != NULL)
{
    SCP079::StartCameraInRoom(player, room);
}
```

#### `void StopCameraForPlayer(Player player)`
Exit camera mode.

```angelscript
SCP079::StopCameraForPlayer(player);
```

### SCP079Base Namespace

#### `void ShowMessage(Player player, const string& in msg, float duration = 3.0)`
Display temporary message to SCP-079 player.

```angelscript
SCP079Base::ShowMessage(player, "System alert: Breach detected", 5.0);
```

#### `bool IsPlayerActive(Player player)`
Check if SCP-079 systems are active for player.

```angelscript
if(SCP079Base::IsPlayerActive(player))
{
    // Systems online
}
```

### SCP079Cameras Namespace

#### `void AddCamera(float x, float y, float z, float pitch, float yaw, int roomIndex, const string& in roomName)`
Programmatically add a camera.

```angelscript
Room room = player.GetRoom();
Entity playerEnt = player.GetEntity();
if(room != NULL && playerEnt != NULL)
{
    SCP079Cameras::AddCamera(
        playerEnt.PositionX(),
        playerEnt.PositionY(),
        playerEnt.PositionZ(),
        playerEnt.Pitch(),
        playerEnt.Yaw(),
        room.GetIndex(),
        room.GetName()
    );
}
```

#### `void RemoveCamera(int index)`
Remove camera by index.

```angelscript
SCP079Cameras::RemoveCamera(0);
```

#### `void RemoveCamerasInRoom(int roomIndex)`
Remove all cameras in a specific room.

```angelscript
SCP079Cameras::RemoveCamerasInRoom(roomIndex);
```

#### `array<CustomCamera> GetCamerasInRoom(int roomIndex)`
Get all cameras in a room.

```angelscript
array<CustomCamera> cams = SCP079Cameras::GetCamerasInRoom(roomIndex);
for(int i = 0; i < cams.size(); i++)
{
    print("Camera " + (i+1) + " at: " + cams[i].localX + ", " + cams[i].localY);
}
```

#### `bool HasCameraInRoom(int roomIdentifier)`
Check if room has any cameras.

```angelscript
if(SCP079Cameras::HasCameraInRoom(r_cont1_173))
{
    print("SCP-173 containment has cameras");
}
```

#### `Room GetRandomRoomWithCamera()`
Get random room that has cameras installed.

```angelscript
Room randomCamRoom = SCP079Cameras::GetRandomRoomWithCamera();
if(randomCamRoom != NULL)
{
    SCP079::StartCameraInRoom(player, randomCamRoom);
}
```

#### `int GetCameraCount()`
Get total number of cameras.

```angelscript
int totalCameras = SCP079Cameras::GetCameraCount();
```

#### `Room GetCurrentViewingRoom(Player player)`
Get the room the player is currently viewing.

```angelscript
Room viewingRoom = SCP079Cameras::GetCurrentViewingRoom(player);
if(viewingRoom != NULL)
{
    print("Viewing: " + viewingRoom.GetName());
}
```

### SCP079Doors Namespace

#### `Door GetPlayerLookedAtDoor(Player player)`
Get the door the player is looking at.

```angelscript
Door targetDoor = SCP079Doors::GetPlayerLookedAtDoor(player);
if(targetDoor != NULL)
{
    print("Looking at door type: " + targetDoor.GetDoorType());
}
```

### CustomCamera Class

```angelscript
class CustomCamera
{
    float localX, localY, localZ;    // Room-relative position
    float pitch, yaw;                 // Camera rotation
    int roomIdentifier;               // Room type ID
    string roomName;                  // Room name
    
    void GetWorldPosition(Room targetRoom, float& out worldX, float& out worldY, float& out worldZ);
    array<Room> GetMatchingRooms();
}
```

## Usage Examples

### Example 1: Custom Camera Placement System

```angelscript
void PlaceCamerasInAllSCPRooms()
{
    array<int> scpRooms = {
        r_cont1_173, r_cont2_049, r_cont1_106,
        r_cont2c_096, r_cont3_966, r_cont1_079
    };
    
    for(int i = 0; i < scpRooms.size(); i++)
    {
        VirtualRoom@ vRoom = GetVirtualRoomByIdentifier(scpRooms[i]);
        if(@vRoom != null && vRoom.room != NULL)
        {
            Entity roomEnt = vRoom.room.GetEntity();
            if(roomEnt != NULL)
            {
                float camX = roomEnt.PositionX();
                float camY = roomEnt.PositionY() + 150.0;
                float camZ = roomEnt.PositionZ();
                
                SCP079Cameras::AddCamera(
                    camX, camY, camZ,
                    -30.0, 0.0,
                    vRoom.roomIndex,
                    vRoom.roomName
                );
            }
        }
    }
    
    print("Placed cameras in " + scpRooms.size() + " SCP containment rooms");
}
```

### Example 2: Alert System

```angelscript
void CheckForBreaches(Player scp079)
{
    if(!SCP079::IsSCP079Player(scp079)) return;
    
    array<int> containmentRooms = {r_cont1_173, r_cont2_049, r_cont1_106};
    
    for(int i = 0; i < containmentRooms.size(); i++)
    {
        VirtualRoom@ vRoom = GetVirtualRoomByIdentifier(containmentRooms[i]);
        if(@vRoom == null) continue;
        
        array<Player> players = vRoom.GetPlayersInRoom();
        if(players.size() > 0)
        {
            SCP079Base::ShowMessage(scp079, 
                "ALERT: Personnel detected in " + vRoom.GetShortName(), 
                5.0);
        }
    }
}
```

### Example 3: Automated Door Control

```angelscript
void LockdownZone(Player scp079, ZoneType zone)
{
    VirtualMap@ vMap = GetVirtualMap();
    if(@vMap == null) return;
    
    array<VirtualRoom@> zoneRooms = vMap.GetRoomsByZone(zone);
    int doorsLocked = 0;
    
    for(int i = 0; i < zoneRooms.size(); i++)
    {
        VirtualRoom@ vRoom = zoneRooms[i];
        if(@vRoom == null || vRoom.room == NULL) continue;
        
        for(int j = 0; j < vRoom.doorConnections.size(); j++)
        {
            Door door = vRoom.doorConnections[j];
            if(door != NULL && !door.IsOpened())
            {
                door.SetLockState(1);
                doorsLocked++;
            }
        }
    }
    
    string zoneName = (zone == ZONE_LCZ) ? "LCZ" : (zone == ZONE_HCZ) ? "HCZ" : "EZ";
    SCP079Base::ShowMessage(scp079, 
        "Lockdown initiated: " + zoneName + " (" + doorsLocked + " doors)", 
        5.0);
}
```

### Example 4: Camera Tour System

```angelscript
void StartCameraTour(Player scp079)
{
    if(!SCP079::IsSCP079Player(scp079)) return;
    
    Room randomRoom = SCP079Cameras::GetRandomRoomWithCamera();
    if(randomRoom != NULL)
    {
        SCP079::StartCameraInRoom(scp079, randomRoom);
        CreateTimer(CameraTourNext, 5000, false, CreateTimerData(scp079));
    }
}

void CameraTourNext(Player scp079)
{
    if(scp079 == NULL || !SCP079::IsSCP079Player(scp079)) return;
    
    Room nextRoom = SCP079Cameras::GetRandomRoomWithCamera();
    if(nextRoom != NULL)
    {
        SCP079::StartCameraInRoom(scp079, nextRoom);
        CreateTimer(CameraTourNext, 5000, false, CreateTimerData(scp079));
    }
}
```

## Configuration

### Camera Detection Delay

Modify in `virtualmap_core.as`:
```angelscript
const int SCP079_DELAY_TICKS = 60;  // Default: 3 seconds
```

### Door Detection Range

Modify in `scp079_doors.as`:
```angelscript
const float DOOR_DETECT_RANGE = 12.0;  // Default: 12 units
const float DOOR_THRESHOLD = 0.9;      // Detection precision
```

### UI Update Rate

Modify in `scp079_map.as`:
```angelscript
const int UI_UPDATE_INTERVAL = 200;  // Default: 200ms
```

## Troubleshooting

### Cameras Not Loading
- Check `scp079/scp079_cameras.txt` exists and is formatted correctly
- Ensure VirtualMap is initialized before SCP-079
- Verify room identifiers match current map

### Player Not Spawning in Camera
- Ensure at least one camera is placed
- Check that camera rooms exist in current map
- Verify `SetupSCP079ForPlayer()` is called after world load

### Door Control Not Working
- Verify player is in camera mode
- Check door is not locked (lock state)
- Ensure door is within detection range
- Confirm door type is supported

### Map Not Showing
- Press M key to toggle
- Ensure VirtualMap is ready (`IsVirtualMapReady()`)
- Check console for map initialization messages

### Player Detection Not Working
- Verify players are in the same room as camera
- Check 3-second delay has passed
- Ensure players are not SCP-079 themselves
- Confirm room tracking is active

## Performance Tips

- Limit camera count per room (1-3 recommended)
- Use camera placement strategically
- Door detection only runs when in camera mode
- HUD updates are optimized with caching
- Player tracking uses efficient delta updates

## Security Considerations

- `/addcam` command requires admin or SCP-079 role
- Camera files are server-side only
- Door bypass logs can be added for admin monitoring
- Player detection respects role visibility rules

## Advanced Customization

### Custom HUD Colors

Modify in `scp079_hud.as`:
```angelscript
mainText.SetColor(0, 255, 0);      // Green for normal
mainText.SetColor(255, 255, 0);    // Yellow for warnings
mainText.SetColor(255, 0, 0);      // Red for alerts
```

### Custom Camera Behavior

Extend `CameraSystem` class in `scp079_cameras.as`:
```angelscript
void UpdateCamera(Player player, float deltaYaw, float deltaPitch)
{
    camYaw += deltaYaw * 0.5;      // Adjust sensitivity
    camPitch += deltaPitch * 0.5;
    
    // Add custom rotation limits
    if(camYaw > 45.0) camYaw = 45.0;
    if(camYaw < -45.0) camYaw = -45.0;
}
```

### Custom Door Filters

Modify `GetDoorPlayerIsLookingAt()` in `scp079_doors.as`:
```angelscript
int doorType = door.GetDoorType();
if(doorType == OFFICE_DOOR || 
   doorType == FENCE_DOOR || 
   doorType == WOODEN_DOOR ||
   doorType == YOUR_CUSTOM_TYPE)
{
    continue;  // Skip this door type
}
```