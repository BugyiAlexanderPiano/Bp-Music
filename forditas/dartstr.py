"""Dart string-literal tokenizer: finds '...' / "..." literals (with ${} nesting), skipping comments."""
import re, sys, json

def scan(src):
    out=[]; i=0; n=len(src)
    while i<n:
        c=src[i]
        if src.startswith('//',i):
            j=src.find('\n',i); i = n if j<0 else j; continue
        if src.startswith('/*',i):
            j=src.find('*/',i+2); i = n if j<0 else j+2; continue
        raw=False
        if c=='r' and i+1<n and src[i+1] in '\'"' and (i==0 or not (src[i-1].isalnum() or src[i-1]=='_')):
            raw=True; i+=1; c=src[i]
        if c in '\'"':
            q=c
            if src.startswith(q*3,i):  # triple quoted: skip entirely
                j=src.find(q*3,i+3); i = n if j<0 else j+3; continue
            start=i-(1 if raw else 0); j=i+1; depth=0
            while j<n:
                ch=src[j]
                if ch=='\\' and not raw: j+=2; continue
                if ch=='$' and not raw and j+1<n and src[j+1]=='{':
                    # skip nested expression with braces and nested strings
                    k=j+2; d=1
                    while k<n and d>0:
                        if src[k] in '\'"':
                            qq=src[k]; k+=1
                            while k<n and src[k]!=qq:
                                if src[k]=='\\': k+=1
                                k+=1
                        elif src[k]=='{': d+=1
                        elif src[k]=='}': d-=1
                        k+=1
                    j=k; continue
                if ch==q: break
                if ch=='\n': break
                j+=1
            out.append((start, j+1, src[start:j+1], raw))
            i=j+1; continue
        i+=1
    return out
