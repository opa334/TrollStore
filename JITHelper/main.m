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
int	 ptrace(int _request, pid_t _pid, caddr_t _addr, int _data);

int main(int argc, const char* argv[]) {
	RBSProcessPredicate *predicate = [RBSProcessPredicate predicateMatchingBundleIdentifier:@(argv[1])];
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
}

