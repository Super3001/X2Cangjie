package proj_nestedlift

class Comment {
    let text: String
    init(text: String) {
        this.text = text
    }
    func show(): String {
        return "node:" + text
    }
}
