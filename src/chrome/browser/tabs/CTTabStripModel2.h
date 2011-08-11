
class CTTabStripModel;
class CTTabStripModelObserver;

@interface CTTabStripModel2 : NSObject

- (id) initWithPointer:(CTTabStripModel*)tabStripModel;

- (void) addObserver:(CTTabStripModelObserver*)observer;
- (void) removeObserver:(CTTabStripModelObserver*)observer;

@end
