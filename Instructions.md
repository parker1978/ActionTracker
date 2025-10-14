# Zomibicide Game Tracking App

## Previous version

I have the app Action Tracker that is used to track actions, characters, and skills in the game Zombicide. The code for that app is compiled in the text file `ActionTracker_code.txt`. I'm rebuilding the app to make it more concise and keep a complete database of characters and skills. 

## Changes Wanted

- Some important changes I want to make include moving from the header menu to a tab bar.
- Getting rid of as much custom code as possible and using built in swift functionality.
- Liquid glass elements
- Smooth animations as much as possible
- Creating built in character (`characters.csv`) and skills (`skills.csv`) databases using SwiftData.

## Actions Tab

- Character being played selection
- Timer to keep track of how long a game goes
- Number of actions (default/starting is 3)
- Active Skills (as experience progresses)
- Experience
- Buttons to add actions and reset turn

## Characters Tab

- Being able to search by character name, set, or skill
- Special search by skill that filters on multiple skills
- Favorite characters

## Final thoughts

- I've got a rough/basic start here. Feel free to change anything.
- Modularize as much code as possible.
- Use Mark: and comments
- Functionally the Action Tracker app works great, but is bloated and doesn't have the characters or skills built in. I want to remove the Campaign stuff.