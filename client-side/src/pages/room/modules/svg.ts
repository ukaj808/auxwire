export class SvgFactory {

    constructor() {
    }

    public generatePlayIcon(): SVGElement {
        // Create a new SVG element
        const svgElement = document.createElementNS("http://www.w3.org/2000/svg", "svg");

        svgElement.classList.add('centered-icon');

        // Set attributes of the SVG element
        svgElement.setAttribute("viewBox", "0 0 32 32");

        // Create a path element and set its "d" attribute
        const pathElement = document.createElementNS("http://www.w3.org/2000/svg", "path");
        pathElement.setAttribute("d", "M5.92 24.096q0 1.088 0.928 1.728 0.512 0.288 1.088 0.288 0.448 0 0.896-0.224l16.16-8.064q0.48-0.256 0.8-0.736t0.288-1.088-0.288-1.056-0.8-0.736l-16.16-8.064q-0.448-0.224-0.896-0.224-0.544 0-1.088 0.288-0.928 0.608-0.928 1.728v16.16z");

        // Append the title and path elements to the SVG element
        svgElement.appendChild(pathElement); 

        return svgElement;
    }


    public generateDragIcon(): SVGElement {
        var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
        svg.classList.add('primary-icon-stroke');
        svg.setAttribute("width", "24px");
        svg.setAttribute("height", "24px");
        svg.setAttribute("viewBox", "0 0 24 24");
        svg.setAttribute("xmlns", "http://www.w3.org/2000/svg");

        // Create the path element
        var path = document.createElementNS("http://www.w3.org/2000/svg", "path");
        path.setAttribute("d", "M5 10H19M14 19L12 21L10 19M14 5L12 3L10 5M5 14H19");

        svg.appendChild(path);

        return svg;
    }


}
