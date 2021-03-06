//	
// Copyright © 2021 Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
    var friendCache: FriendsCache!
    
    convenience init(friendCache: FriendsCache) {
		self.init(nibName: nil, bundle: nil)
        self.friendCache = friendCache
		self.setupViewController()
	}

	private func setupViewController() {
		viewControllers = [
			makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
			makeTransfersList(),
			makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
		]
	}
	
	private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
		vc.navigationItem.largeTitleDisplayMode = .always
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem.image = UIImage(
			systemName: icon,
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		nav.tabBarItem.title = title
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
	
	private func makeTransfersList() -> UIViewController {
		let sent = makeSentTransfersList()
		sent.navigationItem.title = "Sent"
		sent.navigationItem.largeTitleDisplayMode = .always
		
		let received = makeReceivedTransfersList()
		received.navigationItem.title = "Received"
		received.navigationItem.largeTitleDisplayMode = .always
		
		let vc = SegmentNavigationViewController(first: sent, second: received)
		vc.tabBarItem.image = UIImage(
			systemName: "arrow.left.arrow.right",
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		vc.title = "Transfers"
		vc.navigationBar.prefersLargeTitles = true
		return vc
	}
	
    private func makeFriendsList() -> ListViewController {
        let vc = ListViewController()
        let isPremium = User.shared?.isPremium == true
        vc.service = FriendAPIServiceItemsAdaptor(api: FriendsAPI.shared,
                                                  isPremium: User.shared?.isPremium ?? false,
                                                  select: { [weak vc] friend in vc?.showFriend(friend: friend)
                                                  }, cache: isPremium ? friendCache : NullFriendsCache())
        vc.shouldRetry = true
        vc.maxRetryCount = 2
        vc.title = "Friends"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(vc.addFriend))
        vc.fromFriendsScreen = true
        return vc
    }
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
		vc.fromSentTransfersScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 1
        vc.service = TransferAPIServiceItemsAdaptor(api: .shared, select: { [weak vc] tranfer in
            vc?.showTransferVC(transfer: tranfer)
        })
        
        vc.navigationItem.title = "Sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(vc.sendMoney))

		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
        vc.shouldRetry = true
        vc.maxRetryCount = 1
        
        vc.service = SenderAPIServiceItemsAdaptor(api: .shared, select: { [weak vc] tranfer in
            vc?.showTransferVC(transfer: tranfer)
        })
        

        vc.navigationItem.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(vc.requestMoney))

		vc.fromReceivedTransfersScreen = true
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
        let adaptor = CardAPIServiceItemsAdaptor(api: .shared) { [weak vc ] card in
            vc?.showCreditCardDetail(card: card)
        }
        vc.service = adaptor
        vc.shouldRetry = false
        vc.title = "Cards"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(vc.addCard))
		vc.fromCardsScreen = true
		return vc
	}
	
}

// Null Object pattern
class NullFriendsCache: FriendsCache {
    override func save(_ newFriends: [Friend]) {
    }
}
