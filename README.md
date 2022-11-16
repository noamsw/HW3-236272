# hello_me

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

i forgot to add the dry part... not sure how that will effect my grade. adding it now:
DRY:
1)	SnappingSheetController, this allows us to control the position of the snappingSheet, set the snapping position, stop snapping. It gives us access to information about the snappingSheet as well.
2)	snappingCurve
3)	Inkwell allows us to give the user feedback that shows that their touch has been registered. This can improve overall UX. 
GestureDetector is a more basic widget, as inkwell is actually an extension of it. This allows for more custom widgets and effects, and can be used when inkwell is not a wanted behavior. It allows you to implement dragging and so forth.  

