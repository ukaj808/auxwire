type Stylesheet = {
    rules: IdRule[];
}

type IdRule = {
    id: string;
    declarations: Map<string, string>;
}

export class MutableStyleSheet {

    private cssStyleSheet: CSSStyleSheet;

    public constructor(cssStyleSheet: CSSStyleSheet) {
        this.cssStyleSheet = cssStyleSheet;
    }

    public put(id: string, declarations: Map<string, string>) {
        const index = this.getIndexOfRule(id);
        if (index > -1) {
            this.cssStyleSheet.deleteRule(index);
        }
        const rule: IdRule = { id, declarations };
        this.cssStyleSheet.insertRule(this.idRuleToValidCssRule(rule));
    }

    public get(id: string): IdRule | undefined {
        const stylesheet = this.parseStyleSheet();
        return stylesheet.rules.find((r) => r.id === id);
    }

    public delete(id: string) {
        const index = this.getIndexOfRule(id);
        if (index > -1) {
          this.cssStyleSheet.deleteRule(index);
        }
    }

    private getIndexOfRule(id: string): number {
        return Array.from(this.cssStyleSheet.cssRules).findIndex((rule) => {
            if (rule instanceof CSSStyleRule) {
                return rule.selectorText === '#'+id;
            }
            return false;
        });
    }

    private parseStyleSheet(): Stylesheet {
        return {
            rules: Array.from(this.cssStyleSheet.cssRules).reduce((acc, rule) => {
                if (rule instanceof CSSStyleRule) {
                    const parseResult = this.isSingleIdRule(rule.selectorText);
                    if (parseResult.valid) {
                        const declarations = Array.from(rule.style).reduce((acc, property) => {
                            return acc.set(property, rule.style.getPropertyValue(property));
                        }, new Map<string, string>());
                        return acc.concat({ id: parseResult.id, declarations });
                    }
                }
                return acc;
            }, [] as IdRule[])
        }
    }

    private isSingleIdRule(selectorText: string): { valid: boolean, id: string } {
        if (selectorText.startsWith('#')) {
            const r = [...selectorText.substring(1, selectorText.length)].reduce((acc, char) => {
                return { valid: acc.valid && char !== ',' && char !== ' ', id: acc.id + char }
            }, { valid: true, id: "" });
            return r;
        }
        return { valid: false, id: "" };
    }

    private idRuleToValidCssRule(idRule: IdRule): string {
        return `#${idRule.id} { ${Array.from(idRule.declarations).reduce((acc, [property, value]) => {
            return `${acc} ${property}: ${value};`;
        }, '')} }`;
    }

}