//
// Copyright © 2021 Essential Developer. All rights reserved.
//

import UIKit

protocol ItemService {
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void)
}


class ListViewController: UITableViewController {
	var items = [ItemViewModel]()
	
	var retryCount = 0
	var maxRetryCount = 0
	var shouldRetry = false
	
	var longDateStyle = false
	
	var fromReceivedTransfersScreen = false
	var fromSentTransfersScreen = false
	var fromCardsScreen = false
	var fromFriendsScreen = false
    var service: ItemService?
	override func viewDidLoad() {
		super.viewDidLoad()
		
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
		
		if fromSentTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = true

			navigationItem.title = "Sent"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendMoney))

		} else if fromReceivedTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = false
			
			navigationItem.title = "Received"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: self, action: #selector(requestMoney))
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if tableView.numberOfRows(inSection: 0) == 0 {
			refresh()
		}
	}
	
	@objc private func refresh() {
		refreshControl?.beginRefreshing()
		if fromFriendsScreen {
            service?.loadItems(completion: handleAPIResult)
        } else if fromCardsScreen {
			CardAPI.shared.loadCards { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
                    self?.handleAPIResult(result.map { items in
                                            items.map { item in
                                                ItemViewModel(card: item) {
                        self?.showCreditCardDetail(card: item)
                    } }})
				}
			}
		} else if fromSentTransfersScreen || fromReceivedTransfersScreen {
			TransfersAPI.shared.loadTransfers { [weak self] result in
                guard let self = self else { return }
				DispatchQueue.mainAsyncIfNeeded {
                    self.handleAPIResult((result.map { items in
                        items.filter {
                            self.fromSentTransfersScreen  ? $0.isSender : !$0.isSender
                        }
                        .map { item in ItemViewModel(transfer: item, longDateStyle: self.fromSentTransfersScreen) {
                            self.showTransferVC(transfer: item)
                        }
                       }
                    }))
				}
			}
		} else {
			fatalError("unknown context")
		}
	}
	
	private func handleAPIResult(_ result: Result<[ItemViewModel], Error>) {
		switch result {
		case let .success(items):
            self.items = items
			self.retryCount = 0
            self.refreshControl?.endRefreshing()
			self.tableView.reloadData()
			
		case let .failure(error):
			if shouldRetry && retryCount < maxRetryCount {
				retryCount += 1
				
				refresh()
				return
			}
			
			retryCount = 0
			
			if fromFriendsScreen && User.shared?.isPremium == true {
				(UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.loadFriends { [weak self] result in
					DispatchQueue.mainAsyncIfNeeded {
						switch result {
						case let .success(items):
                            self?.items = items.map { item in ItemViewModel(friend: item) {
                                self?.showFriend(friend: item)
                              }
                            }
							self?.tableView.reloadData()
							
						case let .failure(error):
                            self?.showError(error)
						}
						self?.refreshControl?.endRefreshing()
					}
				}
			} else {
                self.showError(error)
                self.refreshControl?.endRefreshing()
            }
		}
	}
    
    func showError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        showDetailViewController(alert, sender: self)
    }
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		items.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = items[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
		cell.configure(item)
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = items[indexPath.row]
        item.onSelect()
    }
    
    func showFriend(friend: Friend) {
        let vc = FriendDetailsViewController()
        vc.friend = friend
        show(vc, sender: self)
    }
    
     func showCreditCardDetail(card: Card) {
        let vc = CardDetailsViewController()
        vc.card = card
        show(vc, sender: self)
    }
	
     func showTransferVC(transfer: Transfer) {
        let vc = TransferDetailsViewController()
        vc.transfer = transfer
        show(vc, sender: self)
    }
    
	@objc func addCard() {
        show(AddCardViewController(), sender: self)
	}
	
	@objc func addFriend() {
        show(AddFriendViewController(), sender: self)
	}
	
	@objc func sendMoney() {
        show(SendMoneyViewController(), sender: self)
	}
	
	@objc func requestMoney() {
        show(RequestMoneyViewController(), sender: self)
	}
}

struct ItemViewModel {
    let title: String
    let subtitle: String
    let onSelect: ()->Void
}

extension UITableViewCell {
    
    func configure(_ viewModel: ItemViewModel) {
        textLabel?.text = viewModel.title
        detailTextLabel?.text = viewModel.subtitle
    }
}

/***
 To be instantiated at composition Root
 */
struct CardAPIServiceItemsAdaptor: ItemService {
    let api: CardAPI
    let select: (Card) -> Void
    
    func loadItems(completion: @escaping
                    (Result<[ItemViewModel], Error>) -> Void) {
        api.loadCards { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items.map { item in
                        ItemViewModel(card: item) {
                            select(item)
                        }
                    }
                })
            }
        }
    }
}
