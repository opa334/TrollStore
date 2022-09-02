#import "TSAppTableViewController.h"

#import "TSApplicationsManager.h"

@implementation TSAppTableViewController

- (void)reloadTable
{
    [self.tableView reloadData];
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"ApplicationCell"];
    [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(reloadTable)
            name:@"ApplicationsChanged"
            object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.allowsMultipleSelectionDuringEditing = NO;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[TSApplicationsManager sharedInstance] installedAppPaths].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ApplicationCell" forIndexPath:indexPath];
    
    NSString* appPath = [[TSApplicationsManager sharedInstance] installedAppPaths][indexPath.row];
    
    // Configure the cell...
    cell.textLabel.text = [[TSApplicationsManager sharedInstance] displayNameForAppPath:appPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        NSString* appPath = [[TSApplicationsManager sharedInstance] installedAppPaths][indexPath.row];
        NSString* appId = [[TSApplicationsManager sharedInstance] appIdForAppPath:appPath];
        [[TSApplicationsManager sharedInstance] uninstallApp:appId error:nil];
    }
}

@end