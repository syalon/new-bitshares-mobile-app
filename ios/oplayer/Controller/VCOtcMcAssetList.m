//
//  VCOtcMcAssetList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcAssetList.h"
#import "ViewOtcMcAssetInfoCell.h"
#import "OtcManager.h"
#import "VCOtcMcAssetTransfer.h"

@interface VCOtcMcAssetList ()
{
    NSDictionary*           _auth_info;
    EOtcUserType            _user_type;
    NSDictionary*           _merchant_detail;
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCOtcMcAssetList

-(void)dealloc
{
    _auth_info = nil;
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _user_type = user_type;
        _merchant_detail = merchant_detail;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQueryOtcAssetsResponsed:(id)responsed
{
    id data = [responsed objectForKey:@"data"];
    [_dataArray removeAllObjects];
    if (data) {
        for (id item in data) {
            [_dataArray addObject:[item mutableCopy]];
        }
    }
    [self refreshView];
}

- (void)refreshView
{
    _mainTableView.hidden = [_dataArray count] <= 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)queryOtcAssets
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[otc queryMerchantOtcAsset:[otc getCurrentBtsAccount]] then:^id(id data) {
        [self hideBlockView];
        [self onQueryOtcAssetsResponsed:data];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    _mainTableView.hidden = NO;
    
    //  UI - 空 TODO:2.9
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何资产"];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  查询
    [self queryOtcAssets];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 * 2 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ViewOtcMcAssetInfoCell* cell = [[ViewOtcMcAssetInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil vc:self];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.showCustomBottomLine = YES;
    [cell setTagData:indexPath.row];
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
//    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
//        id item = [_dataArray objectAtIndex:indexPath.row];
//        assert(item);
//        //  TODO:2.9
////        [self onCellClicked:item];
//    }];
}

/*
 *  (private) 点击收款方式
 */
- (void)onCellClicked:(id)item
{
    NSString* enable_or_disable;
    if ([[item objectForKey:@"status"] integerValue] == eopms_enable) {
        enable_or_disable = NSLocalizedString(@"kOtcPmActionBtnDisable", @"禁用");
    } else {
        enable_or_disable = NSLocalizedString(@"kOtcPmActionBtnEnable", @"启用");
    }
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                      message:nil
                                                       cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                        items:@[enable_or_disable,
                                                                NSLocalizedString(@"kOtcPmActionBtnView", @"查看"),
                                                                NSLocalizedString(@"kOtcPmActionBtnDelete", @"删除")]
                                                     callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
    {
        if (buttonIndex != cancelIndex){
            switch (buttonIndex) {
                case 0:
                    [self _onActionEnableOrDisableClicked:item];
                    break;
                case 1:
                    [self _onActionViewClicked:item];
                    break;
                case 2:
                    [self _onActionDeleteClicked:item];
                    break;
                default:
                    break;
            }
        }
    }];
}

/*
 *  (private) 操作 - 启用 or 禁用收款方式
 */
- (void)_onActionEnableOrDisableClicked:(id)item
{
    EOtcPaymentMethodStatus new_status;
    if ([[item objectForKey:@"status"] integerValue] == eopms_enable) {
        new_status = eopms_disable;
    } else {
        new_status = eopms_enable;
    }
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    OtcManager* otc = [OtcManager sharedOtcManager];
    [[[otc editPaymentMethods:item[@"btsAccount"] ?: [otc getCurrentBtsAccount] new_status:new_status pmid:item[@"id"]] then:^id(id data) {
        [self hideBlockView];
        //  刷新data & UI
        [item setObject:@(new_status) forKey:@"status"];
        [_mainTableView reloadData];
        //  提示信息
        if (_user_type == eout_normal_user) {
            if (new_status == eopms_enable) {
                [OrgUtils makeToast:NSLocalizedString(@"kOtcPmActionTipsEnabled", @"已启用，允许向商家展示。")];
            } else {
                [OrgUtils makeToast:NSLocalizedString(@"kOtcPmActionTipsDisabled", @"已禁用，不再向商家展示。")];
            }
        } else {
            //  TODO:2.9
            if (new_status == eopms_enable) {
                [OrgUtils makeToast:@"已启用，允许向用户展示。"];
            } else {
                [OrgUtils makeToast:@"已禁用，不再向用户展示。"];
            }
        }
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

/*
 *  (private) 操作 - 查看收款方式
 */
- (void)_onActionViewClicked:(id)item
{
    //  TODO:2.9
}

/*
 *  (private) 操作 - 删除收款方式
 */
- (void)_onActionDeleteClicked:(id)item
{
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kOtcPmActionTipsDeleteConfirm", @"确认删除该收款方式吗？")
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
         if (buttonIndex == 1)
         {
             [self _execActionDeleteCore:item];
         }
     }];
}

- (void)_execActionDeleteCore:(id)item
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    OtcManager* otc = [OtcManager sharedOtcManager];
    [[[otc delPaymentMethods:item[@"btsAccount"] ?: [otc getCurrentBtsAccount] pmid:item[@"id"]] then:^id(id data) {
        [self hideBlockView];
        //  提示
        [OrgUtils makeToast:NSLocalizedString(@"kOtcPmActionTipsDeleted", @"删除成功。")];
        //  刷新
        [self queryOtcAssets];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

#pragma mark- for actions

- (void)onButtonClicked_TransferIn:(UIButton*)button
{
    id item = [_dataArray objectAtIndex:button.tag];
    
    //  TODO:2.9
    VCBase* vc = [[VCOtcMcAssetTransfer alloc] initWithAuthInfo:_auth_info
                                                      user_type:_user_type
                                                merchant_detail:_merchant_detail
                                                   balance_info:item
                                                    transfer_in:YES];
    [self pushViewController:vc vctitle:@"划转" backtitle:kVcDefaultBackTitleName];
}

- (void)onButtonClicked_TransferOut:(UIButton*)button
{
    id item = [_dataArray objectAtIndex:button.tag];
    
    //  TODO:2.9
    VCBase* vc = [[VCOtcMcAssetTransfer alloc] initWithAuthInfo:_auth_info
                                                      user_type:_user_type
                                                merchant_detail:_merchant_detail
                                                   balance_info:item
                                                    transfer_in:NO];
    [self pushViewController:vc vctitle:@"划转" backtitle:kVcDefaultBackTitleName];
}

@end