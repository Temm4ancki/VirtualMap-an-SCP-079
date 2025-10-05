# ATTENTION

I'm so fucking sick of coding this crap, I'll be honest.
Even using AI to understand this AngelScript with the game's API... It was torture.

I feel sorry for the people who constantly do stuff for the servers. Although they probably get paid, who knows...

And I think I'll stop making these big stuff for UERM, otherwise they'll put me in the nuthouse for again attempting suicide (NOT JOKE). I already need to up my antidepressant dosage to stay afloat.

If you want, you can **support me by donating** for pills or something.

**The scripts will still be free for EVERYONE.**

## What it is

- **Virtual map module**: which is created automatically every time a server starts.
- **SCP-079 module**: NO GAMEPLAY. Only the map orientation system and basic door opening and closing. I understand you'll be customizing it anyway, so I don't want to waste my energy on something YOU WON'T USE.

## Setup

- **IN Separate README.md for modules**. Virtualmap is the simplest, SCP-079 is the worst. But I don't want to touch that anymore, PLEASE. I'LL MAKE IT BETTER AFTER A REST.

## Potential Issues

- The cameras might not be exactly where I wanted them to be, as I made a mistake in the coordinates. So, I/YOU can quickly fix it in the **scp079_cameras.txt** file (though you'll still have to restart the server). 
The coordinates are from 'debughud 2'. You see, I'm FED UP with manually placing cameras in all 116 rooms, and some rooms even have multiple cameras.

- SCP-079's door opening isn't very precise. Sometimes the closest door might open, not the one the player is looking at. Just have them move the cursor more to the side. Or change the camera position. Yes, there's a setting called "DOOR_THRESHOLD = 0.9," but I don't recommend setting it any lower. Otherwise, doors in r_room3_storage won't be detected. The problem seems to be that I'm incorrectly detecting doors below the camera's field of view. THERE'S NO PROPER UP-DOWN ANGLE DETECTION IN THE GAME. Or maybe I didn't understand how to use it.

- If you have any issues, create an ISSUE on GitHub and I'll see what I can do. Or just a pull request with a fix :)))))

## DONAT

Boosty: https://boosty.to/temm4ancki

Direct donation to DonationAlert: https://dalink.to/temm4ancki

And if you're from Russia or neighboring countries and can send money to Russian cards without restrictions, message me on Discord, same username.