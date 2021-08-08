//	
// Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation
extension ItemViewModel {
    init(friend: Friend, onSelect:  @escaping() -> Void) {
        title = friend.name
        subtitle = friend.phone
        self.onSelect = onSelect
    }
}
