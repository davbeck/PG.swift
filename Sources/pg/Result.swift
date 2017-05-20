import Foundation


public class Result {
	let fields: [Field]
	let rawRows: [[DataSlice?]]
	
	init(fields: [Field], rows: [[DataSlice?]]) {
		self.fields = fields
		self.rawRows = rows
	}
}
