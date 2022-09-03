//
//  ViewController.m
//  TrollInstaller
//
//  Created by Lars Fröder on 17.08.22.
//

#import "ViewController.h"
#import "kutil.h"
#import "exploit/exploit.h"
#import "exploit/kernel_rw.h"
#import "KernelManager.h"
#import "unarchive.h"
#import <spawn.h>
#import <sys/stat.h>

extern uint64_t g_self_proc;

void badLog(const char* a, ...)
{
    va_list va;
    va_start(va, a);
    NSString* af = [NSString stringWithUTF8String:a];
    NSString* msg = [[NSString alloc] initWithFormat:af arguments:va];
    va_end(va);
    NSLog(@"%@",msg);
    return;
}

NSString* getNSStringFromFile(int fd)
{
    NSMutableString* ms = [NSMutableString new];
    ssize_t num_read;
    char c;
    while((num_read = read(fd, &c, sizeof(c))))
    {
        [ms appendString:[NSString stringWithFormat:@"%c", c]];
    }
    return ms.copy;
}

int runBinary(NSString* path, NSArray* args, NSString** output)
{
    NSMutableArray* argsM = args.mutableCopy;
    [argsM insertObject:path.lastPathComponent atIndex:0];
    
    NSUInteger argCount = [argsM count];
    char **argsC = (char **)malloc((argCount + 1) * sizeof(char*));

    for (NSUInteger i = 0; i < argCount; i++)
    {
        argsC[i] = strdup([[argsM objectAtIndex:i] UTF8String]);
    }
    argsC[argCount] = NULL;
    
    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);
    
    int out[2];
    pipe(out);
    posix_spawn_file_actions_adddup2(&action, out[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&action, out[0]);
    
    pid_t task_pid;
    int status = 0;
    int spawnError = posix_spawn(&task_pid, [path UTF8String], &action, NULL, (char* const*)argsC, NULL);
    for (NSUInteger i = 0; i < argCount; i++)
    {
        free(argsC[i]);
    }
    free(argsC);
    
    if(spawnError != 0)
    {
        NSLog(@"posix_spawn error %d\n", spawnError);
        return spawnError;
    }
    
    do
    {
        if (waitpid(task_pid, &status, 0) != -1) {
            //printf("Child status %dn", WEXITSTATUS(status));
        } else
        {
            perror("waitpid");
            return -222;
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    
    close(out[1]);
    
    if(output)
    {
        *output = getNSStringFromFile(out[0]);
    }
    
    return WEXITSTATUS(status);
}


// Get root, credit: @xina520

struct k_posix_cred backup_cred;
int backup_groupSize;
gid_t backup_groupList[200];

int getRoot(void)
{
    NSLog(@"attempting to get root...\n");
    usleep(1000);
    
    backup_groupSize = getgroups(200, &backup_groupList[0]);
    
    backup_cred = proc_get_posix_cred(g_self_proc);
    
    struct k_posix_cred zero_cred = {0};
    NSLog(@"setting posix cred to zero cred...\n");
    usleep(1000);
    proc_set_posix_cred(g_self_proc, zero_cred);

    int err = setgroups(0,0);
    if(err)
    {
        NSLog(@"setgroups error %d\n", err);
        usleep(1000);
    }
    
    int uid = getuid();
    NSLog(@"getuid => %d\n", uid);
    usleep(1000);

    return uid;
}

int dropRoot(void)
{
    if(getuid() != 0) return getuid();

    printf("attempting to drop root...\n");
    usleep(1000);
    
    int err = setgroups(backup_groupSize,backup_groupList);
    if(err)
    {
        printf("setgroups error %d\n", err);
        usleep(1000);
    }
    
    proc_set_posix_cred(g_self_proc, backup_cred);

    int uid = getuid();
    printf("dropped root??? uid: %d\n", uid);
    return uid;
}

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)updateStatus:(NSString*)status
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = status;
    });
}

int writeRemountPrivatePreboot(void)
{
    return runBinary(@"/sbin/mount", @[@"-u", @"-w", @"/private/preboot"], nil);
}

- (void)doInstallation
{
    NSLog(@"TrollStore out here, exploitation starting!");
    usleep(1000);
    
    [self updateStatus:@"Exploiting..."];
    
    // Run kernel exploit
    uint64_t kernel_base;
    if(exploit_get_krw_and_kernel_base(&kernel_base) != 0)
    {
        [self updateStatus:@"Exploit failed :("];
        return;
    }
    
    // Initialize KernelManager
    KernelManager* km = [KernelManager sharedInstance];
    [km loadOffsets];
    [km loadSlidOffsetsWithKernelBase:kernel_base];
    km.kread_32_d = kread32;
    km.kread_64_d = kread64;
    km.kwrite_32 = kwrite32;
    km.kwrite_64 = kwrite64;
    km.kcleanup = exploitation_cleanup;
    
    NSLog(@"Exploitation finished, post exploit stuff next!");
    usleep(1000);
    
    [self updateStatus:@"Getting root..."];
    
    // Get root
    getRoot();
    
    [self updateStatus:@"Installing..."];
    
    writeRemountPrivatePreboot();
    
    NSString* tmpDir = @"/private/preboot/tmp";
    
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:NO attributes:nil error:nil];
    
    NSString* tsTarPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"TrollStore.tar"];
    
    extract(tsTarPath, tmpDir);
    
    NSString* helperPath = [tmpDir stringByAppendingPathComponent:@"TrollStore.app/trollstorehelper"];
    
    chmod(helperPath.UTF8String, 0755);
    chown(helperPath.UTF8String, 0, 0);
    
    NSString* helperOutput;
    int ret = runBinary(helperPath, @[@"install-trollstore", tsTarPath], &helperOutput);
    
    [self updateStatus:@"Cleaning up..."];
    
    [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
    
    // Clean everything up so the kernel doesn't panic when the app exits
    dropRoot();
    [km finishAndCleanupIfNeeded];
    
    [self updateStatus:@"Done!"];
    
    NSLog(@"%@", helperOutput);
    
    // Print installed message
    if(ret == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController* installedAlertController = [UIAlertController alertControllerWithTitle:@"Installed TrollStore" message:@"TrollStore was installed and can now be accessed from your home screen, you can uninstall the installer application now. Some devices suffer from a bug where newly installed applications don't immediately show up, in that case reboot and TrollStore should show up." preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }];
            
            [installedAlertController addAction:closeAction];
            
            [self presentViewController:installedAlertController animated:YES completion:nil];
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController* installedAlertController = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to install TrollStore. trollstore helper exited with code %d. Output:\n:%@", ret, helperOutput ?: @"<none>"] preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                exit(0);
            }];
            
            UIAlertAction* copyAction = [UIAlertAction actionWithTitle:@"Copy Output" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = helperOutput;
                exit(0);
            }];
            
            [installedAlertController addAction:closeAction];
            [installedAlertController addAction:copyAction];
            
            [self presentViewController:installedAlertController animated:YES completion:nil];
        });
    }
}

- (IBAction)installButtonPressed:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self doInstallation];
    });
}

@end
