import { MutableStyleSheet } from "./stylesheet-manipulations";

export type ResponsiveQueueAnimationStyleOptions = {
  orientation: "horizontal" | "vertical";
  spaceBetweenElements: number;
  stylesheet: MutableStyleSheet;
  media: MediaQueryList;
  startingTailPosition: number;
  elementWidth: number;
  elementHeight: number;
};

export type ResponsiveQueueAnimationOptions = {
  queue: HTMLElement;
  childElementType: keyof HTMLElementTagNameMap;
  childElementClassName: string;
  styleOptions: ResponsiveQueueAnimationStyleOptions[];
};

export type ResponsiveQueueAnimationManager = {
  enter: (id: string, styles?: Map<string, string>) => void;
  leave: (id: string) => void;
  cycle: () => void;
};

export const responsiveQueueAnimationManager = (
  opts: ResponsiveQueueAnimationOptions
): ResponsiveQueueAnimationManager => {
  const tailPositions = opts.styleOptions.map((s) => s.startingTailPosition);
  let animationCount = 0;

  opts.styleOptions.forEach((styleOpts) => {
    styleOpts.media.addEventListener("change", () => {
        opts.queue.getAnimations({subtree: true}).forEach(a => {
            a.finish();
        })
    })
  });

  // @ts-ignore
  window.animationDebug = {
    printRunningAnimations: () => console.log(opts.queue.getAnimations({subtree: true})),
    printTailPositions: () => console.log(tailPositions),
  }
  const rezindex = () => {
    opts.styleOptions.forEach((styleOpts) => {
      const stacking = styleOpts.spaceBetweenElements < 0;
      if (stacking) {
        for (
          let i = 0, j = opts.queue.childElementCount;
          i < opts.queue.childElementCount;
          i++, j--
        ) {
          const el = opts.queue.children[i] as HTMLElement;
          const declarations = new Map(
            styleOpts.stylesheet.get(el.id)?.declarations
          );
          declarations.set("z-index", j.toString());
          styleOpts.stylesheet.put(el.id, declarations);
        }
      }
    });
  };

  // 1. Initially set the position of each element in the queue
  //    based on the orientation of the queue and the space between.
  //    They should be positioned absolutely and fixed to one side of the queue.
  //
  //    e.g. horizontal = top,left,bottom: 0, vertical = top,left,right: 0
  Array.from(opts.queue.children).forEach((c, i) => {
    const el = c as HTMLElement;
    opts.styleOptions.forEach((styleOpts, j) => {
      let declarations = new Map<string, string>(
        styleOpts.stylesheet.get(el.id)?.declarations
      );
      const stacking = styleOpts.spaceBetweenElements < 0;
      if (stacking) {
        const dataZIndex = c.getAttribute("data-z-index");
        if (!dataZIndex)
          throw new Error(
            `A negative spaceBetweenElements (${styleOpts.spaceBetweenElements}) requires a data-z-index attribute on the element`
          );
        declarations.set("z-index", dataZIndex);
      }
      switch (styleOpts.orientation) {
        case "horizontal":
          const dataLeft = el.getAttribute("data-left");
          if (!dataLeft)
            throw new Error(
              "A horizontal orientation requires a data-left attribute on the element"
            );
          declarations.set("left", dataLeft);
          break;
        case "vertical":
          const dataTop = el.getAttribute("data-top");
          if (!dataTop)
            throw new Error(
              "A vertical orientation requires a data-top attribute on the element"
            );
          declarations.set("top", dataTop);
          break;
      }
      tailPositions[j] =
        tailPositions[j] +
        styleOpts.spaceBetweenElements +
        (styleOpts.orientation === "horizontal"
          ? styleOpts.elementWidth
          : styleOpts.elementHeight);
      styleOpts.stylesheet.put(el.id, declarations);
    });
  });

  return {
    enter: (id: string, styles?: Map<string, string>) => {
      // 1. if stacking, rezindex previous elements
      rezindex();

      const el = document.createElement(opts.childElementType);
      el.id = id;
      el.classList.add(opts.childElementClassName); // need to pass this class in somehow; it must align with the orientation restraints!!

      if (styles) {
        styles.forEach((value, key) => {
          el.style.setProperty(key, value);
        });
      }

      opts.styleOptions.forEach((styleOpts, i) => {
        const declarations = new Map<string, string>();
        const stacking = styleOpts.spaceBetweenElements < 0;
        if (stacking) {
          declarations.set("z-index", "0");
        }
        const elementDimension =
          styleOpts.orientation === "horizontal"
            ? styleOpts.elementWidth
            : styleOpts.elementHeight;
        switch (styleOpts.orientation) {
          case "horizontal":
            declarations.set("left", tailPositions[i] + "px");
            break;
          case "vertical":
            declarations.set("top", tailPositions[i] + "px");
            break;
        }
        styleOpts.stylesheet.put(el.id, declarations);
        tailPositions[i] =
          tailPositions[i] + styleOpts.spaceBetweenElements + elementDimension;
      });

      opts.queue.appendChild(el);

      const mediaMatch = opts.styleOptions.find(
        (styleOpts) => styleOpts.media.matches
      );
      if (!mediaMatch)
        throw new Error(
          "None of the stylesheets match the current media query"
        );

      const keyframe =
        mediaMatch.orientation === "horizontal"
          ? { left: "1000px", offset: 0 }
          : { top: "1000px", offset: 0 };

      const animationId = (animationCount++).toString();
      const enterAnimation = el.animate([keyframe], {
        duration: 10000,
        id: animationId,
      });
    },
    leave: (id: string) => {
      const { leavingEl, index } = (
        Array.from(opts.queue.children) as HTMLElement[]
      ).reduce(
        (acc, el, index) => {
          if (el.id === id) {
            return { leavingEl: el, index };
          }
          return acc;
        },
        { leavingEl: undefined as HTMLElement | undefined, index: -1 }
      );
      if (!leavingEl) throw new Error(`No element found with id ${id}`);

      // todo
      const mediaMatch = opts.styleOptions.find(
        (styleOpts) => styleOpts.media.matches
      );
      if (!mediaMatch)
        throw new Error(
          "None of the stylesheets match the current media query"
        );
      const leaveKeyframe =
        mediaMatch.orientation === "horizontal"
          ? { left: "1000px" }
          : { top: "1000px" };

      const animationId = (animationCount++).toString();
      const leaveAnimation = leavingEl.animate([leaveKeyframe], {
        duration: 10000,
        id: animationId,
      });
      opts.styleOptions.forEach((styleOpts, i) => {
        tailPositions[i] =
            tailPositions[i] -
            (styleOpts.spaceBetweenElements +
            (styleOpts.orientation === "horizontal"
                ? styleOpts.elementWidth
                : styleOpts.elementHeight));
      });
      leaveAnimation.finished.then(() => {
        opts.styleOptions.forEach((styleOpts) =>
          styleOpts.stylesheet.delete(id)
        );
        leavingEl.remove();
      });

      Array.from(opts.queue.children)
        .slice(index + 1)
        .forEach((c) => {
          const el = c as HTMLElement;
          opts.styleOptions.forEach((styleOpts) => {
            const declarations = new Map(
              styleOpts.stylesheet.get(el.id)!.declarations
            );
            const attr =
              styleOpts.orientation === "horizontal" ? "left" : "top";
            const prevValueAsStr =
              styleOpts.orientation === "horizontal"
                ? declarations.get("left")
                : declarations.get("top");
            const prevValue = parseInt(prevValueAsStr!);
            const difference =
              styleOpts.orientation === "horizontal"
                ? styleOpts.elementWidth
                : styleOpts.elementHeight;
            const newValue =
              prevValue - (styleOpts.spaceBetweenElements + difference);
            declarations.set(attr, newValue + "px");
            styleOpts.stylesheet.put(el.id, declarations);

            if (styleOpts.media.matches) {
              const moveUpKeyframe = { [attr]: prevValueAsStr, offset: 0 };
              const animationId = (animationCount++).toString();
              const moveUpAnimation = el.animate([moveUpKeyframe], {
                duration: 10000,
                id: animationId,
              });
            }
          });
        });
    },
    cycle: () => {},
  };
};
