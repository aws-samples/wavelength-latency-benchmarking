// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

#import <QuartzCore/QuartzCore.h>

#import "NetperfWrapper.h"

#include "netperf/netperf.h"
#include <netinet/in.h>
#include <arpa/inet.h>


@interface NetperfWrapper ()

@end

@implementation NetperfWrapper

static dispatch_queue_t q = NULL;
static CLLocationManager *lm = NULL;
static NSISO8601DateFormatter *df = NULL;
static NSUserDefaults *ud = NULL;
static double lat = 0.0f, lon = 0.0f;

static char host1[64] = { 0 };
static char host2[64] = { 0 };
static char *duration = "60"; //seconds

static BOOL continousTestingRunning = NO;

static void
setup_complete(BOOL host2callback, int port, void *user_data)
{
    NetperfWrapper *obj = (__bridge NetperfWrapper *)user_data;
    UIButton *b_setup = host2callback?obj.b_setup2:obj.b_setup;
    NSLog(@"setup_complete %@ %d", host2callback?@"host2callback=YES":@"host2callback=NO", port);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (port == 0) {
            [b_setup setEnabled:YES];
            [obj consoleAppend:[NSString stringWithFormat:@"# Control connection for server %d abandoned", host2callback?2:1]];
        } else {
            [obj.b_start setEnabled:YES];
            [obj consoleAppend:[NSString stringWithFormat:@"# Control connection for server %d complete", host2callback?2:1]];
        }
    });
}

static void
setup1_complete(int port, void *user_data)
{
    setup_complete(NO, port, user_data);
}

static void
setup2_complete(int port, void *user_data)
{
    setup_complete(YES, port, user_data);
}

/* These get called when we are running tests continuously */

static void
host2_autosetup_complete(int port, void *user_data)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NetperfWrapper *obj = (__bridge NetperfWrapper *)user_data;
        [obj consoleAppend:[NSString stringWithFormat:@"# Running test to %s:%d for %ss...", host2, port, duration]];
        if (lm) [lm requestLocation];
    });
    actual_send_omni_inner(user_data, latency_result2);
}

static void
host1_autosetup_complete(int port, void *user_data)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NetperfWrapper *obj = (__bridge NetperfWrapper *)user_data;
        [obj consoleAppend:[NSString stringWithFormat:@"# Running test to %s:%d for %ss...", host1, port, duration]];
        if (lm) [lm requestLocation];
    });
    actual_send_omni_inner(user_data, latency_result1);
}

/* copy azid don't rely on its lifecycle */

static void
latency_result(BOOL host2callback, double x, unsigned long y, const char *azid, void *user_data)
{
    NetperfWrapper *obj = (__bridge NetperfWrapper *)user_data;
    UILabel *l_latency, *l_transactions;
    char *azid_copy = NULL;
    char *host;
    
    if (host2callback) {
        host = host2;
        l_latency = obj.l_latency2;
        l_transactions = obj.l_transactions2;
    } else {
        host = host1;
        l_latency = obj.l_latency;
        l_transactions = obj.l_transactions;
    }
    
    if (azid != NULL) {
        azid_copy = malloc(strlen(azid) + 1);
        strcpy(azid_copy, azid);
    } else {
        azid_copy = strdup("unknown");
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NetperfWrapper *obj = (__bridge NetperfWrapper *)user_data;
        NSString *geo = NULL;
        NSDate *now = [NSDate date];

        if (lm && lm.authorizationStatus != kCLAuthorizationStatusDenied &&
            lm.authorizationStatus != kCLAuthorizationStatusNotDetermined) {
            geo = [NSString stringWithFormat:@", %0.6f, %0.6f", lat, lon];
        } else {
            geo = @", NaN, NaN";
        }
         
        if (x > 1000.0) {
            [l_latency setText:[NSString stringWithFormat:@"%.2f ms", x/1000.0]];
            [l_transactions setText:[NSString stringWithFormat:@"%lu", y]];
            [obj consoleAppend:[NSString stringWithFormat:@"%s, %s, %.2fms, %lu%@, %@", host, azid_copy, x/1000.0, y, (geo?geo:@""), [df stringFromDate:now]]];
        } else {
            [l_latency setText:[NSString stringWithFormat:@"%.2f µs", x]];
            [l_transactions setText:[NSString stringWithFormat:@"%lu", y]];
            [obj consoleAppend:[NSString stringWithFormat:@"%s, %s, %.2fµs, %lu%@, %@", host, azid_copy, x, y, (geo?geo:@""), [df stringFromDate:now]]];
        }
        shutdown_control();
        free(azid_copy);

        /* end of host1 test, next do either host2 or repeat if host2 is unset */
        if (!host2callback) {
            if (strlen(host2) > 0) {
                [obj runTestForHost:host2 forDuration:60 withCompletion:host2_autosetup_complete];
            } else if ([obj.s_cont isOn]) {
                [obj runTestForHost:host1 forDuration:60 withCompletion:host1_autosetup_complete];
            }
            return;
        } else if (host2callback && strlen(host1) > 0 && [obj.s_cont isOn]) {
            /* otherwise, if we just did host2, and we're running continuous tests, do host1 again */
            [obj runTestForHost:host1 forDuration:60 withCompletion:host1_autosetup_complete];
        }

        /* drop out if we are not doing continuous tests and let user restart */
        if (![obj.s_cont isOn]) {
            [obj.b_start  setEnabled:NO];
            [obj.b_setup  setEnabled:YES];
            [obj.b_setup2 setEnabled:YES];
            continousTestingRunning = NO;
        }
    });
}

static void
latency_result1(double x, unsigned long y, const char *azid, void *user_data)
{
    latency_result(NO, x, y, azid, user_data);
}

static void
latency_result2(double x, unsigned long y, const char *azid, void *user_data)
{
    latency_result(YES, x, y, azid, user_data);
}
    /* make sure you copy t because the C stuff will free it on return of this function (before the inner code block executes potentially */

static void
instead_of_exit(const char *t, void *user_data)
{
    if (t != NULL && user_data != NULL) {
        NSLog(@"instead_of_exit %s", t);
        char *t_copy = malloc(strlen(t) + 1);
        if (t_copy != NULL) {
            strcpy(t_copy, t);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NetperfWrapper *obj = (__bridge NetperfWrapper *)user_data;
                shutdown_control();
                [obj.l_latency setText:@"Unknown"];
                [obj.l_transactions setText:@"Unknown"];
                [obj consoleAppendCString:t_copy];
                if (continousTestingRunning) {
                    /* just try to keep going */
                    [obj runTestForHost:host1 forDuration:60 withCompletion:host1_autosetup_complete];
                } else {
                    [obj.b_start setEnabled:NO];
                    [obj.b_setup setEnabled:YES];
                    [obj.b_setup2 setEnabled:YES];
                }
                free(t_copy);
            });
        }
    }
}

- (void)consoleAppendCString:(const char *)t
{
    if (t != NULL && strlen(t) > 0) {
        [self.text insertText:[NSString stringWithFormat:@"# %s", t]];
        NSLog(@"%s", t);
    }
}

- (void)consoleAppend:(NSString *)t
{
    if (t != NULL && [t length] > 0) {
        [self.text insertText:[NSString stringWithFormat:@"%@\n", t]];
        NSLog(@"%@", t);
    }
}

- (void)saveHostAddresses
{
    int i = 1; /*  weird  */
    
    for (UITextField *field in [NSArray arrayWithObjects:self.address, self.address2, nil]) {
        char temphost[64] = { 0 };
        struct in_addr tempaddr;
        [field.text getCString:temphost maxLength:sizeof(temphost)/sizeof(*temphost) encoding:NSUTF8StringEncoding];
        if (inet_aton(temphost, &tempaddr)) {
            if (ud) [ud setObject:field.text forKey:[NSString stringWithFormat:@"host%d", i]];
        } else {
            if (ud) {
                [ud removeObjectForKey:[NSString stringWithFormat:@"host%d", i]];
                [ud removeObjectForKey:[NSString stringWithFormat:@"port%d", i]];
            }
        }
        i++;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    NSLog(@"tfDidEndEditing %@", textField);
    [self saveHostAddresses];
}

- (void)dismissKeyboard:(id)sender
{
    NSLog(@"dismissKB %@", sender);
    [self.view endEditing:YES];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"location error %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *recent = [locations lastObject];
    lat = recent.coordinate.latitude;
    lon = recent.coordinate.longitude;
}

- (void)longPressText:(id)sender
{
    UILongPressGestureRecognizer *r = (UILongPressGestureRecognizer *)sender;
    
    if (r.state == UIGestureRecognizerStateEnded) {
        UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
        generalPasteboard.string = self.text.text;
        
        /* flash up the 'copied' indicator */

        [self.l_copied setHidden:NO];
        self.l_copied.alpha = 1.0f;

        /* redo the frame calculaton in case of rotation */
        
        CGFloat lWidth = self.text.frame.size.width * 0.5f;
        CGFloat lHeight = self.text.frame.size.height * 0.5f;
        CGFloat pWidth = self.text.frame.size.width;
        CGFloat pHeight = self.text.frame.size.height;
        
        /* looks stupid if aspect ratio becomes < 1.0 IMHO */
        if (lHeight > lWidth) lHeight = lWidth;
        
        self.l_copied.frame = CGRectMake((pWidth - lWidth) / 2.0f, (pHeight - lHeight) / 2.0f,
                                         lWidth, lHeight);

        [UIView animateWithDuration:0.7f
                              delay:0.1f
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                    self.l_copied.alpha = 0.0f;
        }
                         completion:^(BOOL finished){
            [self.l_copied setHidden:YES];
        }];
    }
}

- (void)viewDidLoad
{
    long int i = 1, p;

    [super viewDidLoad];

    /* Use this queue to run the actual netperf tests */
    q = dispatch_queue_create("runtest", DISPATCH_QUEUE_SERIAL);

    /* Lose the keyboard when we tap outside it */
    UITapGestureRecognizer* tapBackground = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard:)];
    [tapBackground setNumberOfTapsRequired:1];
    [self.view addGestureRecognizer:tapBackground];
    
    /* copy the text field if we long press on it */
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressText:)];
    [self.text addGestureRecognizer:longPress];
    
    /* Some visual tweaks */
    
    self.text.layer.borderWidth = 1.0f;
    self.text.layer.cornerRadius = 5;
    self.text.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    
    self.l_copied.layer.cornerRadius = 5;
    self.l_copied.layer.backgroundColor = [[UIColor lightGrayColor] CGColor];
    self.l_copied.font = [UIFont boldSystemFontOfSize:28.0f];
    self.l_copied.textColor = [UIColor whiteColor];
    
    /* Location manager so we can record our position */
        lm = [[CLLocationManager alloc] init];
    lm.delegate = self;
    [lm requestWhenInUseAuthorization];
    
    /* Date formatter using ISO8601 */
    df = [[NSISO8601DateFormatter alloc] init];
    
    /* Get the saved IP addresses and ports if there are any */
    ud = [NSUserDefaults standardUserDefaults];

    for (UITextField *field in [NSArray arrayWithObjects:self.address, self.address2, nil]) {
        NSString *saved_host = NULL;
        [field setDelegate:self];
        if (ud && (saved_host = [ud stringForKey:[NSString stringWithFormat:@"host%ld", i]]) != NULL) {
            [field setText:saved_host];
            if (i == 1) {
                [saved_host getCString:host1 maxLength:sizeof(host1) encoding:NSUTF8StringEncoding];
            } else if (i == 2) {
                [saved_host getCString:host2 maxLength:sizeof(host2) encoding:NSUTF8StringEncoding];
            }
        }
        i++;
    }
    
    [self consoleAppend:@"# Ready"];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSLog(@"textFieldShouldReturn:%@", textField);
    return YES;
}

- (IBAction)start_pressed:(id)sender 
{
    NSLog(@"start_pressed %@", sender);
    [self.b_start setEnabled:NO];
    continousTestingRunning = [self.s_cont isOn];
    [self runTestForHost:host1 forDuration:60 withCompletion:host1_autosetup_complete];
    if (lm) [lm requestLocation];
}

- (void)runTestForHost:(const char *)host
           forDuration:(unsigned int)seconds
        withCompletion:(void (int, void *))f_complete
{
    dispatch_async(q, ^{
        shutdown_control();
        char dur_t[64];
        snprintf(dur_t, sizeof(dur_t), "%u", seconds);

        NSLog(@"host = %s, duration=%u", host, seconds);

        const char *netperf_args[] = { "netperf-wrapper", "-4", "-H", host, "-l", dur_t, "-t", "tcp_rr", "--", "-P", "12866" };
            
        netperf_main(sizeof(netperf_args)/sizeof(const char *), netperf_args,
                         (__bridge void *)(self), f_complete, instead_of_exit);
    });
}

- (IBAction)setup_pressed:(id)sender
{
    static unsigned int i = 1;
    NSLog(@"setup_pressed %u, sender=%@", i++, (sender==self.b_setup)?@"b_setup":@"b_setup2");
    char *host;
    UITextField *address;
    void (*f_complete)(int, void *);
        
    if (sender == self.b_setup) {
        host = host1;
        f_complete = setup1_complete;
        address = self.address;
    } else if (sender == self.b_setup2) {
        host = host2;
        f_complete = setup2_complete;
        address = self.address2;
    } else {
        return;
    }
    
    if ([address.text length] > 0 && [address.text length] < 16) {
        char temphost[64] = { 0 };
        struct in_addr addr;
        
        if ([address.text getCString:temphost maxLength:sizeof(temphost)/sizeof(*temphost)
                            encoding:NSUTF8StringEncoding] &&
            inet_aton(temphost, &addr)) {
            NSLog(@"good address %s (vs. saved %s)", temphost, host);
            if (strcmp(host, temphost) != 0) {
                /*  if host changed then don't remember the port */
                strcpy(host, temphost);
            }
        } else {
            NSLog(@"bad address %@", address.text);
            [self consoleAppend:[NSString stringWithFormat:@"# %@ does not appear to be a valid IPv4 address", address.text]];
            return;
        }
    }
    
    [(UIButton *)sender setEnabled:NO];
    [self consoleAppend:[NSString stringWithFormat:@"# Set up control connection to %s:12865...", host]];
    [self runTestForHost:host forDuration:1 withCompletion:f_complete];
    [self.view endEditing:YES];
}
@end
