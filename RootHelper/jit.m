@import Foundation;
@import Darwin;

@interface RBSProcessPredicate
+ (instancetype)predicateMatchingBundleIdentifier:(NSString *)bundleID;
@end

@interface RBSProcessHandle
+ (instancetype)handleForPredicate:(RBSProcessPredicate *)predicate error:(NSError **)error;
- (int)rbs_pid;
@end

#define PT_DETACH       11
#define PT_ATTACHEXC    14
int	 ptrace(int request, pid_t pid, caddr_t addr, int data);

int enableJIT(NSString *bundleID) {
#ifdef EMBEDDED_ROOT_HELPER
 	return -1;
#else
 	RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingBundleIdentifier:bundleID];
	RBSProcessHandle* process = [RBSProcessHandle handleForPredicate:predicate error:nil];
	int pid = process.rbs_pid;

	if (!pid)
	{
		return ESRCH;
	}

	int ret = ptrace(PT_ATTACHEXC, pid, 0, 0);
	if (ret == -1)
	{
		return errno;
	}

	usleep(100000);
	ret = ptrace(PT_DETACH, pid, 0, 0);
	if (ret == -1)
	{
		return errno;
	}
	return 0;
#endif
}

