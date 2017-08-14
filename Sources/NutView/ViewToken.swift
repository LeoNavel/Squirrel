//
//  ViewToken.swift
//  Squirrel
//
//  Created by Filip Klembara on 8/11/17.
//
//

struct ViewToken {
    let name: String
    let head: [NutHeadProtocol]
    let body: [NutTokenProtocol]
    let layout: NutLayoutProtocol?
    let subviews: [NutSubviewProtocol]

    init(name: String, head: [NutHeadProtocol] = [], body: [NutTokenProtocol], layout: NutLayoutProtocol? = nil, subviews: [NutSubviewProtocol] = []) {
        self.name = name
        self.head = head
        self.body = body
        self.layout = layout
        self.subviews = subviews
    }
}