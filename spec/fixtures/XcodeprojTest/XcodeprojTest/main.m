#import <Foundation/Foundation.h>

#import <XcodeprojTestPod/XcodeprojTestPod.h>

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        if ([XcodeprojTestPod twenty] == 20) {
            NSLog(@"Success");
            return 0;
        } else {
            NSLog(@"Failure!");
            return 1;
        }
        
    }
    return 0;
}
