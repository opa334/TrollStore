#import "TSUtil.h"

#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/sysctl.h>

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

NSString* helperPath(void)
{
	return [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"trollstorehelper"];
}

int spawnRoot(NSString* path, NSArray* args)
{
	NSMutableArray* argsM = args.mutableCopy ?: [NSMutableArray new];
	[argsM insertObject:path.lastPathComponent atIndex:0];
	
	NSUInteger argCount = [argsM count];
	char **argsC = (char **)malloc((argCount + 1) * sizeof(char*));

	for (NSUInteger i = 0; i < argCount; i++)
	{
		argsC[i] = strdup([[argsM objectAtIndex:i] UTF8String]);
	}
	argsC[argCount] = NULL;

	int rv;
	posix_spawnattr_t attr;
	rv = posix_spawnattr_init(&attr);
	if(rv != 0) return rv;

	posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
	posix_spawnattr_set_persona_uid_np(&attr, 0);
	posix_spawnattr_set_persona_gid_np(&attr, 0);
	
	pid_t task_pid;
	int status = -200;
	int spawnError = posix_spawn(&task_pid, [path UTF8String], NULL, &attr, (char* const*)argsC, NULL);
	posix_spawnattr_destroy(&attr);
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
			printf("Child status %dn", WEXITSTATUS(status));
		} else
		{
			perror("waitpid");
			return -222;
		}
	} while (!WIFEXITED(status) && !WIFSIGNALED(status));
	
	return WEXITSTATUS(status);
}

void enumerateProcessesUsingBlock(void (^enumerator)(pid_t pid, NSString* executablePath, BOOL* stop))
{
	static int maxArgumentSize = 0;
	if (maxArgumentSize == 0) {
		size_t size = sizeof(maxArgumentSize);
		if (sysctl((int[]){ CTL_KERN, KERN_ARGMAX }, 2, &maxArgumentSize, &size, NULL, 0) == -1) {
			perror("sysctl argument size");
			maxArgumentSize = 4096; // Default
		}
	}
	int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL};
	struct kinfo_proc *info;
	size_t length;
	int count;
	
	if (sysctl(mib, 3, NULL, &length, NULL, 0) < 0)
		return;
	if (!(info = malloc(length)))
		return;
	if (sysctl(mib, 3, info, &length, NULL, 0) < 0) {
		free(info);
		return;
	}
	count = length / sizeof(struct kinfo_proc);
	for (int i = 0; i < count; i++) {
		@autoreleasepool {
		pid_t pid = info[i].kp_proc.p_pid;
		if (pid == 0) {
			continue;
		}
		size_t size = maxArgumentSize;
		char* buffer = (char *)malloc(length);
		if (sysctl((int[]){ CTL_KERN, KERN_PROCARGS2, pid }, 3, buffer, &size, NULL, 0) == 0) {
			NSString* executablePath = [NSString stringWithCString:(buffer+sizeof(int)) encoding:NSUTF8StringEncoding];
			
			BOOL stop = NO;
			enumerator(pid, executablePath, &stop);
			if(stop)
			{
				free(buffer);
				break;
			}
		}
		free(buffer);
		}
	}
	free(info);
}

void killall(NSString* processName)
{
	enumerateProcessesUsingBlock(^(pid_t pid, NSString* executablePath, BOOL* stop)
	{
		if([executablePath.lastPathComponent isEqualToString:processName])
		{
			kill(pid, SIGTERM);
		}
	});
}

void respring(void)
{
	killall(@"SpringBoard");
	exit(0);
}

NSString* getTrollStoreVersion(void)
{
	return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
}
