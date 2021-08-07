//
// Copyright © 2021 Essential Developer. All rights reserved.
//

import UIKit

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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
		
		if fromFriendsScreen {
			shouldRetry = true
			maxRetryCount = 2
			
			title = "Friends"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFriend))
			
		} else if fromCardsScreen {
			shouldRetry = false
			
			title = "Cards"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCard))
			
		} else if fromSentTransfersScreen {
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
			FriendsAPI.shared.loadFriends { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {

                    self?.handleAPIResult(result.map { items in
                                            
                                            if User.shared?.isPremium == true {
                                                (UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.save(items)
                                            }

                                            return items.map { item in
                                                ItemViewModel(friend: item) {
                                                    
                        self?.showFriend(friend: item)
                    } }})
				}
			}
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
    
    private func showFriend(friend: Friend) {
        let vc = FriendDetailsViewController()
        vc.friend = friend
        show(vc, sender: self)
    }
    
    private func showCreditCardDetail(card: Card) {
        let vc = CardDetailsViewController()
        vc.card = card
        show(vc, sender: self)
    }
	
    private func showTransferVC(transfer: Transfer) {
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

extension ItemViewModel {
    init(friend: Friend, onSelect:  @escaping() -> Void) {
        title = friend.name
        subtitle = friend.phone
        self.onSelect = onSelect
    }
}

extension ItemViewModel {
    init(card: Card, onSelect: @escaping() -> Void) {
        title = card.number
        subtitle = card.holder
        self.onSelect = onSelect
    }
}

extension ItemViewModel {
    init(transfer: Transfer, longDateStyle: Bool, onSelect: @escaping() -> Void) {
        let numberFormatter = Formatters.number
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = transfer.currencyCode
        
        let amount = numberFormatter.string(from: transfer.amount as NSNumber)!
        title = "\(amount) • \(transfer.description)"
        
        let dateFormatter = Formatters.date
        if longDateStyle {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            subtitle = "Sent to: \(transfer.recipient) on \(dateFormatter.string(from: transfer.date))"
        } else {
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            subtitle = "Received from: \(transfer.sender) on \(dateFormatter.string(from: transfer.date))"
        }
        self.onSelect = onSelect
    }
}


extension UITableViewCell {
    
    func configure(_ viewModel: ItemViewModel) {
        textLabel?.text = viewModel.title
        detailTextLabel?.text = viewModel.subtitle
    }
}
