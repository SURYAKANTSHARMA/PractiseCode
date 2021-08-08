//	
// Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation
/***
 To be instantiated at composition Root
 */
struct FriendAPIServiceItemsAdaptor: ItemService {
    let api: FriendsAPI
    let isPremium: Bool
    let select: (Friend) -> Void
    let cache: FriendsCache
    
    func loadItems(completion: @escaping
                    (Result<[ItemViewModel], Error>) -> Void) {
        api.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    cache.save(items)
                    return items.map { item in
                        ItemViewModel(friend: item) {
                           select(item)
                        }
                    }
                 })
            }
        }
    }
}
