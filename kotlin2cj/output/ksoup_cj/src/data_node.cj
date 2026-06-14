package ksoup_cj

import std.collection.*

class DataNode <: LeafNode {
    init(data: String) {
        super(data)
    }
    let _isPacked: Bool
    public override func nodeName(): String {
        return "#data"
    }
    func getWholeData(): String {
        return coreValue()
    }
    func setWholeData(data: ?String): DataNode {
        coreValue(data)
        return this
    }
    func getUnpackedData(): String {
        let currentData = getWholeData()
        return if (_isPacked(currentData)) {
            currentData.replace(DataNode.packedRegex(), { packed =>
                String.join(collectArray<String>(DataNode.packedExtractRegex().findAll(packed.value).mapNotNull({ matchResult =>
                    let payload = matchResult.groups.get(1)?.value
                    let symtab = matchResult.groups.get(4)?.value?.split(r'|')
                    let radix = matchResult.groups.get(2)?.value?.toIntOrNull() ?? 10
                    let count = matchResult.groups.get(3)?.value?.toIntOrNull()
                    let unbaser = Unbaser(radix)
                    if (((symtab.isNone()) || (count.isNone())) || (symtab.size != count)) {
                        None
                    } else {
                        payload?.replace(DataNode.unpackReplaceRegex(), { `match` =>
                            let word = `match`.value
                            let unbased = symtab[unbaser.unbase(word)]
                            unbased.ifEmpty({ => word })
                        })
                    }
                }).iterator().map({e => e.toString()})), delimiter: "")
            })
        } else {
            currentData
        }
    }
    public override func outerHtmlHead(accum: QuietAppendable, out: OutputSettings) {
        let data = getWholeData()
        if ((out.syntax() == OutputSettings.Syntax.xml) && !data.contains("<![CDATA[")) {
            if (parentNameIs("script")) {
                accum.append("//<![CDATA[\n").append(data).append("\n//]]>")
            } else if (parentNameIs("style")) {
                accum.append("/*<![CDATA[*/\n").append(data).append("\n/*]]>*/")
            } else {
                accum.append("<![CDATA[").append(data).append("]]>")
            }
        } else {
            accum.append(data)
        }
    }
    public override func createClone(): Node {
        return DataNode((value as String))
    }
    public override func clone(): DataNode {
        return (super.clone() as DataNode)
    }
    func isPacked(data: String): Bool {
        return parentNameIs("script") && data.contains(DataNode.packedRegex())
    }
    static let packedRegex = Regex("eval[(]function[(]p,a,c,k,e,[rd][)][{].*?[}][)]{2}", HashSet([RegexOption.IGNORE_CASE, RegexOption.MULTILINE]))
    static let packedExtractRegex = Regex("[}][(]'(.*)', *(\\d+), *(\\d+), *'(.*?)'[.]split[(]'[|]'[)]", HashSet([RegexOption.IGNORE_CASE, RegexOption.MULTILINE]))
    static let unpackReplaceRegex = Regex("\\b\\w+\\b", HashSet([RegexOption.IGNORE_CASE, RegexOption.MULTILINE]))
}
