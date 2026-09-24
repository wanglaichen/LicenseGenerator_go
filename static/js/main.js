const KEY_HISTORY_STORAGE = "regmachine_key_history";
const KEY_LAST_SELECTED_STORAGE = "regmachine_key_last_selected";
const CUSTOM_KEY_VALUE = "__custom__";
const BUILTIN_OPTION_VALUE = "__builtin__";
const MAX_KEY_HISTORY = 10;

function byId(id) {
    return document.getElementById(id);
}

function isBuiltInSelection(value) {
    return value === BUILTIN_OPTION_VALUE;
}

function loadKeyHistory() {
    try {
        const raw = localStorage.getItem(KEY_HISTORY_STORAGE);
        const parsed = raw ? JSON.parse(raw) : [];
        return Array.isArray(parsed) ? parsed.filter((item) => typeof item === "string") : [];
    } catch (error) {
        return [];
    }
}

function saveKeyHistory(history) {
    localStorage.setItem(KEY_HISTORY_STORAGE, JSON.stringify(history.slice(0, MAX_KEY_HISTORY)));
}

function rememberKey(key) {
    if (!key || isBuiltInSelection(byId("keySelect").value)) {
        return loadKeyHistory();
    }

    const history = loadKeyHistory().filter((item) => item !== key);
    history.unshift(key);
    saveKeyHistory(history);
    return history;
}

function renderKeyOptions(selectedValue = null) {
    const select = byId("keySelect");
    const history = loadKeyHistory();
    const lastSelected = selectedValue || localStorage.getItem(KEY_LAST_SELECTED_STORAGE) || BUILTIN_OPTION_VALUE;

    select.innerHTML = "";

    const builtInOption = document.createElement("option");
    builtInOption.value = BUILTIN_OPTION_VALUE;
    builtInOption.textContent = "内置";
    select.appendChild(builtInOption);

    history.forEach((key) => {
        const option = document.createElement("option");
        option.value = key;
        option.textContent = key;
        select.appendChild(option);
    });

    const customOption = document.createElement("option");
    customOption.value = CUSTOM_KEY_VALUE;
    customOption.textContent = "自定义密钥...";
    select.appendChild(customOption);

    if (lastSelected === CUSTOM_KEY_VALUE || !Array.from(select.options).some((option) => option.value === lastSelected)) {
        select.value = lastSelected === CUSTOM_KEY_VALUE ? CUSTOM_KEY_VALUE : BUILTIN_OPTION_VALUE;
    } else {
        select.value = lastSelected;
    }

    toggleCustomKeyInput();
}

function toggleCustomKeyInput() {
    const isCustom = byId("keySelect").value === CUSTOM_KEY_VALUE;
    byId("keyCustom").classList.toggle("d-none", !isCustom);
}

function getSelectedKey() {
    const select = byId("keySelect");
    if (select.value === CUSTOM_KEY_VALUE) {
        return byId("keyCustom").value.trim();
    }
    if (isBuiltInSelection(select.value)) {
        return "";
    }
    return select.value;
}

function persistSelectedKey(key) {
    localStorage.setItem(KEY_LAST_SELECTED_STORAGE, key);
}

function showMessage(kind, text) {
    const errorBox = byId("errorBox");
    const successBox = byId("successBox");
    errorBox.classList.add("d-none");
    successBox.classList.add("d-none");

    const box = kind === "error" ? errorBox : successBox;
    box.textContent = text;
    box.classList.remove("d-none");
}

function clearMessages() {
    byId("errorBox").classList.add("d-none");
    byId("successBox").classList.add("d-none");
}

async function requestJson(url, options = {}) {
    const response = await fetch(url, {
        headers: { "Content-Type": "application/json" },
        ...options,
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        throw new Error(data.message || data.error || "请求失败");
    }
    return data;
}

async function generateRegisterCode() {
    clearMessages();
    const button = byId("generateRegisterButton");
    const selectValue = byId("keySelect").value;
    const key = getSelectedKey();

    if (selectValue === CUSTOM_KEY_VALUE) {
        if (!key) {
            showMessage("error", "请输入自定义密钥");
            return;
        }
        if (key.length !== 8) {
            showMessage("error", "密钥必须是 8 个字符");
            return;
        }
    } else if (!isBuiltInSelection(selectValue) && key.length !== 8) {
        showMessage("error", "密钥必须是 8 个字符");
        return;
    }

    button.disabled = true;

    try {
        const payload = { sn: byId("sn").value };
        if (key) {
            payload.key = key;
        }

        const result = await requestJson("/api/register-code", {
            method: "POST",
            body: JSON.stringify(payload),
        });

        byId("registerCode").textContent = result.activation_code;
        byId("compatibilityNote").textContent = result.compatibility_note;

        if (byId("keySelect").value === CUSTOM_KEY_VALUE) {
            rememberKey(key);
            renderKeyOptions(key);
            byId("keySelect").value = key;
            byId("keyCustom").classList.add("d-none");
            byId("keyCustom").value = "";
        } else {
            rememberKey(key);
            renderKeyOptions(key);
        }

        persistSelectedKey(byId("keySelect").value);
        showMessage("success", "激活码生成完成");
    } catch (error) {
        showMessage("error", error.message);
    } finally {
        button.disabled = false;
    }
}

async function copyResult(targetId) {
    const value = byId(targetId).textContent.trim();
    if (!value || value === "等待生成") {
        showMessage("error", "当前没有可复制的结果");
        return;
    }

    await navigator.clipboard.writeText(value);
    showMessage("success", "已复制到剪贴板");
}

function clearResult() {
    clearMessages();
    byId("registerCode").textContent = "等待生成";
    byId("compatibilityNote").textContent = "对注册码输入执行 DES/XDES 加密，密钥默认使用内置密钥。";
}

function bindEvents() {
    byId("generateRegisterButton").addEventListener("click", generateRegisterCode);
    byId("clearButton").addEventListener("click", clearResult);
    byId("keySelect").addEventListener("change", () => {
        toggleCustomKeyInput();
        if (byId("keySelect").value !== CUSTOM_KEY_VALUE) {
            persistSelectedKey(byId("keySelect").value);
        }
    });

    document.querySelectorAll(".copy-btn").forEach((button) => {
        button.addEventListener("click", () => copyResult(button.dataset.copyTarget));
    });

    byId("keyCustom").addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
            event.preventDefault();
            generateRegisterCode();
        }
    });
}

document.addEventListener("DOMContentLoaded", () => {
    renderKeyOptions();
    bindEvents();
});
