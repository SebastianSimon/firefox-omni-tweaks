const getSetting = (setting) => {
    const booleanElement = setting.querySelector(booleanSelector),
      stringElement = setting.querySelector(stringSelector),
      type = new Set(setting.closest("[data-type]")?.dataset.type.split(" ") ?? []);
    
    if(!booleanElement && !stringElement){
      throw new Error(`Setting with preset key '${getSetting(setting).asPresetKey()}' has no recognized form element.`);
    }
    
    return {
      asPresetKey(){
        const compositeKey = [
            setting.closest("[data-preset-key]").dataset.presetKey
          ],
          presetSubKey = setting.closest("[data-preset-sub-key]");
        
        if(presetSubKey){
          compositeKey.push(presetSubKey.dataset.presetSubKey);
        }
        
        return compositeKey.join("|");
      },
      asPresetValue(){
        if(stringElement){
          if(!stringElement.value && type.has("defaultIfEmpty")){
            if(defaultValues.has(setting)){
              return defaultValues.get(setting);
            }
            
            throw new Error(`Setting with preset key '${getSetting(setting).asPresetKey()}' has no default value, but has 'defaultIfEmpty' type.`);
          }
          
          if(!type.has("composite") && stringElement.value.startsWith("-")){
            return `./${stringElement.value}`;
          }
          
          return stringElement.value;
        }
        
        return (booleanElement.checked
          ? (type.has("switch")
            ? "on"
            : "true")
          : "");
      },
      asCLIKey(style){
        if(style !== "long"){
          style = "short";
        }
        
        return setting.closest(`[data-${style}-cli-key]`).dataset[`${style}CliKey`];
      },
      asCLIValue(){
        let prefix = (type.has("composite")
          ? `${setting.closest("[data-preset-sub-key]").dataset.presetSubKey}`
          : "");
        
        if(stringElement){
          if(prefix){
            prefix += "=";
          }
          
          if(!type.has("composite") && stringElement.value.startsWith("-")){
            prefix += "./";
          }
          
          return `${prefix}${stringElement.value}`;
        }
        
        const compositeComponent = !type.has("composite") || booleanElement.checked
          ? ""
          : "=";
        
        return `${prefix}${compositeComponent}`;
      }
    };
  },
  isDefaultValue = (setting) => defaultValues.get(setting) === getSetting(setting).asPresetValue(),
  plural = (num, suffix) => (num === 1
    ? ""
    : suffix),
  applyElementEffects = (setting) => {
    const isDefault = isDefaultValue(setting),
      presetKey = getSetting(setting).asPresetKey(),
      moreElementEffects = [],
      quietEnabled = !isDefaultValue(document.getElementById("quiet")),
      addAllFoundEnabled = !isDefaultValue(document.getElementById("addAllFound")),
      fixOnlyYoungestEnabled = !isDefaultValue(document.getElementById("fixOnlyYoungest")),
      firefoxDirsProvided = document.querySelector("[data-preset-key='firefoxDirs'] [data-preset-sub-key]"),
      resultAddAll = firefoxDirsProvided && !addAllFoundEnabled
        ? ""
        : " automatically find all Firefox directories",
      resultAddSpecified = firefoxDirsProvided
        ? " validate all Firefox directories you specified"
        : "",
      resultAddAllAndSpecified = resultAddAll && resultAddSpecified
        ? ", and also"
        : "",
      resultFilter = !quietEnabled && !addAllFoundEnabled && !fixOnlyYoungestEnabled && !firefoxDirsProvided
        ? " If it finds more than one and the script was run interactively, it’ll ask you which ones you want to tweak; otherwise, it’ll tweak all of them"
        : fixOnlyYoungestEnabled
        ? " Then, only the Firefox directory that has been updated most recently will be taken into account"
        : " The script will then tweak all of them";
    
    if(!isDefaultValue(document.getElementById("autoSelectCopiesToClipboard"))){
      moreElementEffects.push(...({
        "options|autoCompleteCopiesToClipboard": {
          default: [
            {
              id: "afterURLBarAutoComplete",
              selector: "strong",
              property: "textContent",
              value: "but the selection is not copied to clipboard"
            },
            {
              id: "afterURLBarAutoComplete",
              selector: "img:last-of-type",
              property: "alt",
              value: "The start of a URL is typed; the rest of the URL is selected, but nothing copied to the selection clipboard."
            }
          ],
          otherwise: [
            {
              id: "afterURLBarAutoComplete",
              selector: "strong",
              property: "textContent",
              value: "and the selection is copied to clipboard"
            },
            {
              id: "afterURLBarAutoComplete",
              selector: "img:last-of-type",
              property: "alt",
              value: "The start of a URL is typed; the rest of the URL is selected, and the selection is copied to the selection clipboard."
            }
          ]
        },
        "options|tabSwitchCopiesToClipboard": {
          default: [
            {
              id: "afterTabSwitch",
              selector: "strong",
              property: "textContent",
              value: "but its content is not copied to clipboard"
            },
            {
              id: "afterTabSwitch",
              selector: "img:last-of-type",
              property: "alt",
              value: "A tab is shown; URL bar is selected, but nothing copied to the selection clipboard."
            }
          ],
          otherwise: [
            {
              id: "afterTabSwitch",
              selector: "strong",
              property: "textContent",
              value: "and its content is copied to clipboard"
            },
            {
              id: "afterTabSwitch",
              selector: "img:last-of-type",
              property: "alt",
              value: "A tab is shown; URL bar is selected, and the selection is copied to the selection clipboard."
            }
          ]
        }
      }[presetKey]
        ?.[isDefault
          ? "default"
          : "otherwise"] ?? []));
    }
    
    if(presetKey === "options|autoSelectCopiesToClipboard"){
      update({
        target: document.getElementById("autoCompleteCopiesToClipboard")
      });
      update({
        target: document.getElementById("tabSwitchCopiesToClipboard")
      });
    }
    
    if(presetKey === "options|secondsSeekedByKeyboard" && !isDefault){
      const seconds = Number(getSetting(setting).asPresetValue());
      
      moreElementEffects.push(...[
        "afterSeekInBuiltInPlayer",
        "afterSeekInPiPPlayer"
      ].map((id) => ({
        id,
        selector: "strong",
        property: "textContent",
        value: `${seconds} second${plural(seconds, "s")}`
      })));
    }
    
    document.getElementById("whenScriptRuns").querySelector("strong").textContent = `the script will${resultAddAll}${resultAddAllAndSpecified}${resultAddSpecified}, and add them to the selection.${resultFilter}`;
    (elementEffects[presetKey]
      ?.[isDefault
        ? "default"
        : "otherwise"] ?? [])
        .concat(moreElementEffects)
        .forEach(({ id, selector, property, value }) => (document.getElementById(id).querySelector(selector)[property] = value));
  },
  setPreset = (setting) => presetEntries.set(getSetting(setting).asPresetKey(), getSetting(setting).asPresetValue()),
  compactItems = (items) => {
    items.sort(({ compact: a }, { compact: b }) => Boolean(a) - Boolean(b));
    
    const compactStart = items.findIndex(({ compact }) => compact);
    
    if(compactStart !== -1){
      const compactedItems = items.splice(compactStart);
      
      items.push(" -", compactedItems
        .map(({ textContent }) => textContent.replace(" -", ""))
        .join(""));
    }
    
    return items;
  },
  toNodeItems = ([ ...items ]) => {
    items = compactItems(items);
    
    const list = items.map((item) => {
        if(typeof item === "string"){
          return item;
        }
        
        const element = Object.assign(document.createElement("span"), item);
        
        if(element.classList.contains("shStart")){
          element.setAttribute("aria-hidden", "true");
        }
        
        return element;
      });
    
    if(typeof list[0] === "string"){
      list[0] = list[0].trimStart();
    }
    
    if(typeof list[list.length - 1] === "string"){
      list[list.length - 1] = list[list.length - 1].trimEnd();
    }
    
    return list;
  },
  toCLIUnit = (style) => (setting) => {
    if(isDefaultValue(setting)){
      return [];
    }
    
    const resultKey = {
        textContent: ` ${getSetting(setting).asCLIKey(style)}`
      },
      result = [
        resultKey
      ],
      cliValue = getSetting(setting).asCLIValue();
    
    if(setting.querySelector(stringSelector) || cliValue){
      result.push(" ", {
        textContent: `${shell.quotePrefix(cliValue)}'${shell.escape(cliValue)}'`,
        classList: [
          "str"
        ]
      });
    }
    else if(style === "compact"){
      resultKey.compact = true;
    }
    
    return result;
  },
  updateCommandLine = () => {
    const commandLine = document.getElementById("commandLine"),
      style = document.querySelector("[name='cliStyle']:checked").value;
    
    commandLine.replaceChildren(...toNodeItems([
      {
        textContent: "",
        classList: [
          "shStart"
        ]
      },
      {
        textContent: "./fixfx.sh",
        classList: [
          "fn"
        ]
      },
      ...Array.from(document.querySelectorAll(".setting")).flatMap(toCLIUnit(style))
    ]));
    commandLine.normalize();
  },
  update = ({ target, isTrusted }) => {
    const setting = target.closest(".setting");
    
    if(setting){
      if(isTrusted){
        modified = true;
      }
      
      applyElementEffects(setting);
      setPreset(setting);
      updateCommandLine();
    }
  },
  updateAll = (container = document.body) => {
    container.querySelectorAll(".setting").forEach((setting) => {
      applyElementEffects(setting);
      setPreset(setting);
    });
    updateCommandLine();
  },
  manageDynamicSettings = ({ target }) => {
    const addButton = target.closest(".addButton"),
      removeButton = target.closest(".removeButton");
    
    if(addButton){
      const {
          newItem,
          updateContainer
        } = manageDynamicSetting.addFrom(target);
      
      updateContainer();
      (newItem.querySelector(booleanSelector) ?? newItem.querySelector(stringSelector))?.focus();
    }
    else if(removeButton){
      manageDynamicSetting.removeFrom(target).updateContainer();
    }
  },
  changeCLIStyle = ({ target }) => {
    const cliStyleButton = target.closest("[name='cliStyle']");
    
    if(cliStyleButton){
      updateCommandLine();
    }
  },
  toggleInfo = ({ target }) => {
    const infoButton = target.closest(".info");
    
    if(infoButton){
      document.getElementById(infoButton.getAttribute("aria-labelledby")).toggleAttribute("hidden");
    }
  },
  byEntryKeys = ([ a ], [ b ]) => a.localeCompare(b),
  entriesToAssociativeArray = (nesting) => ([ key, value ]) => `${nesting}[${key}]=${shell.quotePrefix(value)}'${shell.escape(value)}'`,
  generatePresets = (nesting) => Array.from(presetEntries)
    .sort(byEntryKeys)
    .map(entriesToAssociativeArray(nesting))
    .join("\n"),
  getCustomScriptSource = (event) => {
    const programmaticDownloadLink = document.getElementById("programmaticDownloadLink");
    
    event.preventDefault();
    programmaticDownloadLink.href = URL.createObjectURL(new Blob([
      defaultScript
        .replace(/( *# Begin presets\.\n)(\s*).*?(\n\s*# End presets\.)/su, (_all, begin, nesting, end) => `${begin}${generatePresets(nesting)}${end}`)
    ], {
      type: "application/x-shellscript"
    }));
    programmaticDownloadLink.download = "fixfx.sh";
    programmaticDownloadLink.click();
  },
  findSettingByPresetKey = (key) => {
    const compositeKey = key.split("|");
    
    return Array.from(document.querySelectorAll(".setting"))
      .find((setting) => setting.closest(`[data-preset-key='${compositeKey[0]}']`) && (compositeKey.length <= 1 || setting.closest(`[data-preset-sub-key='${compositeKey[1]}']`)));
  },
  setDefaultValues = () => {
    Array.from(presetEntries).forEach(([ key, value ]) => {
      const [
          presetKeyPart
        ] = key.split("|"),
        existingSetting = findSettingByPresetKey(key),
        addButton = document.querySelector(`[data-preset-key='${presetKeyPart}'] .addButton`);
      
      if(existingSetting){
        defaultValues.set(existingSetting, value);
      }
      else if(addButton){
        const {
            newItem
          } = manageDynamicSetting.addFrom(addButton),
          existingSetting = findSettingByPresetKey(key);
        
        if(existingSetting){
          newItem.querySelector(".removeButton").remove();
          defaultValues.set(existingSetting, value);
        }
        else{
          const errorMessage = `Settable default for preset '${key}' cannot be generated! If you see this, please create an issue on GitHub: ${gitHubRepo}/issues/new?assignees=SebastianSimon&labels=bug,web+app&template=bug_report.md&title=Setting+for+preset+%27${encodeURIComponent(key)}%27+cannot+be+generated`;
          
          alert(errorMessage); // eslint-disable-line no-alert
          throw new Error(errorMessage);
        }
      }
      else{
        const errorMessage = `No settable default found for the preset '${key}'! If you see this, please create an issue on GitHub: ${gitHubRepo}/issues/new?assignees=SebastianSimon&labels=bug,web+app&template=bug_report.md&title=Missing+setting+for+preset+%27${encodeURIComponent(key)}%27`;
        
        alert(errorMessage); // eslint-disable-line no-alert
        throw new Error(errorMessage);
      }
    });
  },
  resetAll = () => {
    document.getElementById("settings").reset();
    Array.from(defaultValues).forEach(([ setting, value ]) => {
      const booleanElement = setting.querySelector(booleanSelector),
        stringElement = setting.querySelector(stringSelector);
      
      if(booleanElement){
        booleanElement.checked = value;
      }
      else if(stringElement){
        stringElement.value = value;
      }
    });
    updateAll();
  },
  getJSON = (response) => response.json(),
  getText = (response) => response.text(),
  booleanSelector = "input[type='checkbox']",
  stringSelector = "input[type='text'],input[type='number']",
  defaultValues = new Map(),
  elementEffects = await fetch("web/elementEffects.json").then(getJSON),
  shell = {
    quotePrefix(string){
      return ((/\\|'/u).test(string)
        ? "$"
        : "");
    },
    escape(string){
      return `${string.replaceAll("\\", "\\\\").replaceAll("'", "\\'")}`;
    },
    unescape(string){
      return `${string.replaceAll("\\'", "'").replaceAll("\\\\", "\\")}`;
    }
  },
  manageDynamicSetting = {
    addFrom(initiator){
      const container = initiator.closest("[data-preset-key]"),
        type = new Set(initiator.closest("[data-type]")?.dataset.type.split(" ") ?? []),
        start = Number(initiator.closest("[start]")?.start ?? 0),
        template = container.querySelector("template"),
        newItem = template.content.firstElementChild.cloneNode(true);
      
      if(type.has("sequential")){
        (newItem.matches("[data-preset-sub-key]")
          ? newItem
          : newItem.querySelector("[data-preset-sub-key]"))
            .dataset.presetSubKey = container.querySelectorAll(".setting").length + start;
      }
      
      template.before(newItem);
      
      return {
        newItem,
        updateContainer: updateAll.bind(null, container)
      };
    },
    removeFrom(initiator){
      const item = initiator.closest("[data-preset-key] > *"),
        container = item.parentElement,
        indexOfChange = Array.from(container.querySelectorAll(".setting"))
          .findIndex((setting) => setting.closest("[data-preset-key] > *") === item),
        type = new Set(initiator.closest("[data-type]")?.dataset.type.split(" ") ?? []),
        start = Number(initiator.closest("[start]")?.start ?? 0),
        presetKeyOfLastSetting = getSetting(Array.from(container.querySelectorAll(".setting")).at(-1)).asPresetKey();
      
      presetEntries.delete(getSetting(item.querySelector(".setting")).asPresetKey());
      item.remove();
      
      if(type.has("sequential")){
        Array.from(container.querySelectorAll(".setting"))
          .slice(indexOfChange)
          .forEach((setting, index) => {
            setting.closest("[data-preset-sub-key]").dataset.presetSubKey = indexOfChange + index + start;
          });
        presetEntries.delete(presetKeyOfLastSetting);
      }
      
      return {
        updateContainer: updateAll.bind(null, container.querySelector("[data-preset-sub-key]")
          ? container
          : undefined)
      };
    }
  },
  defaultScript = await fetch("fixfx.sh").then(getText),
  gitHubRepo = (() => {
    const {
        hostname,
        pathname
      } = new URL(location);
    
    if(hostname.endsWith(".github.io")){
      return `https://github.com/${hostname.split(".")[0]}/${pathname.split("/")[1]}`;
    }
    
    return "https://github.com/SebastianSimon/firefox-omni-tweaks";
  })(),
  presetEntries = new Map(defaultScript
    .match(/ *# Begin presets\.\n\s*(?<presets>.*?)\n\s*# End presets\./su)
    .groups
    .presets
    .split(/\n\s*/u)
    .map((entry) => {
      const [
          _all,
          key,
          value
        ] = entry.match(/\[(.*?)\]=\$?'(.*?)(?<!\\)'/su);
      
      return [
        key,
        shell.unescape(value)
      ];
    })
    .sort(byEntryKeys));
let modified = false;

addEventListener("input", update);
addEventListener("click", (...args) => {
  manageDynamicSettings(...args);
  changeCLIStyle(...args);
  toggleInfo(...args);
});
document.getElementById("downloadLink").addEventListener("click", getCustomScriptSource);
setDefaultValues();
resetAll();
addEventListener("beforeunload", (event) => {
  if(modified){
    event.preventDefault();
  }
});
