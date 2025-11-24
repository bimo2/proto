//
//  MainMenu.h
//  o1
//
//  Created by composer-1 on 2025-11-23.
//

#import <Cocoa/Cocoa.h>

@protocol MainMenuDelegate <NSObject>

- (void)window:(id)sender;

@end

@interface MainMenu : NSMenu

@end
