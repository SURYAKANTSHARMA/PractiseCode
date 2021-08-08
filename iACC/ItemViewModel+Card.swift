//	
// Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation
extension ItemViewModel {
    init(card: Card, onSelect: @escaping() -> Void) {
        title = card.number
        subtitle = card.holder
        self.onSelect = onSelect
    }
}
