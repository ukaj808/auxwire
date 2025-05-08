export class LoaderFactory {

    constructor() {
    }

    public generateSmallLoadingBars(): HTMLDivElement {
        const loadingBars = this.generateLoadingBars();
        loadingBars.className = "lds-facebook-sm";
        return loadingBars;
    }
    
    public generateMediumLoadingBars(): HTMLDivElement {
        const loadingBars = this.generateLoadingBars();
        loadingBars.className = "lds-facebook-md";
        return loadingBars;
    }

    private generateLoadingBars(): HTMLDivElement {
        var outerDiv = document.createElement("div") as HTMLDivElement;

        var innerDiv1 = document.createElement("div");
        var innerDiv2 = document.createElement("div");
        var innerDiv3 = document.createElement("div");

        outerDiv.appendChild(innerDiv1);
        outerDiv.appendChild(innerDiv2);
        outerDiv.appendChild(innerDiv3);

        return outerDiv;
    }


}
