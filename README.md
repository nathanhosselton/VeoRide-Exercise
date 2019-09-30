# Summary

- This app allows users to select arbitrary destination on a map and receive an overlaid route to that destination.
- Once a destination is selected, the user may press the Start button to initiate navigation.
- While navigating, the user's traveled path is recorded and also overlaid on the map.
- When the user presses the "End" button to complete navigation, a summary of their trip is displayed including their traveled distance and the time elapsed.
- The user may optionally interact with their traveled path before resetting to begin a new trip.

# Process

The commit history of the repository may be used as a reference for steps taken during implementation. My high-level process was:

1. Construct and connect the UI to be used, including the map and button
1. Obtain the user's location, asking permission if needed
1. Detect user taps on the map and resolve them to a map coordinate
1. Obtain directions from the user's current location to the map coordinate using MapKit's Directions API
1. Display the direction's available routes as line overlays on the map view
1. Draw a live path onto the map representing the user's traveled path during navigation
1. Calculate trip summary values and display them when the user ends the trip

Along the way I made decisions regarding code organization and clarity, such as separating view updates/changes and trip logic into the TripViewController and TripCoordinator respectively.

Some things I wanted to complete but was unable:

- More robust error handling, such as when user location is lost
- Allowing the user to select alternate routes (MapKit provides them, but discreet interaction detection is needed)
- Showing the navigation steps (Again, MapKit provides them, but displaying them needs manual detection of reaching each step. Also would need to account for the user changing paths for the experience to be viable.)

I left notes for these and other TODOs/FIXMEs in the relevant parts of the code.