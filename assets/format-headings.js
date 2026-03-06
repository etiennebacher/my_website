document.addEventListener('DOMContentLoaded', function() {
    // 选择所有级别的标题
    const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
    
    headings.forEach(el => {
        processNode(el);
    });

    function processNode(node) {
        if (node.nodeType === 3) { // 3 代表文本节点
            const text = node.nodeValue;
            
            // 如果包含 ASCII 字符 (英文、数字、半角标点)
            if (/[\x00-\x7F]/.test(text)) {
                const fragment = document.createDocumentFragment();
                let lastIndex = 0;
                // 正则：匹配连续的 ASCII 字符
                const regex = /[\x00-\x7F]+/g;
                let match;
                
                while ((match = regex.exec(text)) !== null) {
                    // 1. 添加匹配前的中文文本
                    if (match.index > lastIndex) {
                        fragment.appendChild(document.createTextNode(text.substring(lastIndex, match.index)));
                    }
                    
                    // 2. 添加匹配到的英文文本，包裹 span
                    const span = document.createElement('span');
                    span.className = 'heading-en';
                    span.textContent = match[0];
                    fragment.appendChild(span);
                    
                    lastIndex = regex.lastIndex;
                }
                
                // 3. 添加剩余的文本
                if (lastIndex < text.length) {
                    fragment.appendChild(document.createTextNode(text.substring(lastIndex)));
                }
                
                // 用新的片段替换原来的文本节点
                node.parentNode.replaceChild(fragment, node);
            }
        } else if (node.nodeType === 1) { // 1 代表元素节点 (如 h2 里的 a 标签)
            // 递归处理子节点
            Array.from(node.childNodes).forEach(processNode);
        }
    }
});
