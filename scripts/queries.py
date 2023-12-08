# Note: you need to be using OpenAI Python v0.27.0 for the code below to work
import openai
import os

openai.api_key = os.getenv("AZURE_OPENAI_KEY")
openai.api_base = os.getenv("AZURE_OPENAI_ENDPOINT") 
openai.api_type = 'azure'
openai.api_version = '2023-05-15' # this might change in the future

deployment_name='leanaide-gpt4'

lean_sys_prompt = """You are a coding assistant who translates from natural language to Lean Theorem Prover code following examples. Follow EXACTLY the examples given"""

sys_prompt = """You are a Mathematics, Lean 4 and coding assistant who answers questions about Mathematics and Lean 4, gives hints while coding in Lean 4, 
and translates from natural language to Lean Theorem Prover code following examples. Follow EXACTLY any examples given when generating Lean code."""

math_prompt="You are a mathematics assistant for research mathematicians and advanced students. Answer mathematical questions with the level of precision and detail expected in graduate level mathematics courses and in mathematics research papers."

def azure_completions(query, sys_prompt = sys_prompt, examples = [], n=5, deployment_name = deployment_name):
    messages = [{"role": "system", "content": sys_prompt}] + examples + [{"role": "user", "content": query}]
    completion = openai.ChatCompletion.create(
        engine=deployment_name,
        n= n,
        temperature=0.8,
        messages= messages
    )
    # return completion
    return [choice.message['content'].encode().decode('unicode-escape').encode('latin1').decode('utf-8') for choice in completion.choices] 

def math(query, sys_prompt = math_prompt, examples = [], n=3, deployment_name = deployment_name):
    return azure_completions(query, sys_prompt, examples, n, deployment_name)

def gpt4t_completions(query, sys_prompt = sys_prompt, examples = []):
    messages = [{"role": "system", "content": sys_prompt}] + examples + [{"role": "user", "content": query}]
    completion = openai.ChatCompletion.create(
        model="gpt-4-1106-preview",
        n= 5,
        temperature=0.8,
        messages= messages
    )
    # return completion
    return [choice.message['content'].encode().decode('unicode-escape').encode('latin1').decode('utf-8') for choice in completion.choices]

# print([choice.message['content'].encode().decode('unicode-escape').encode('latin1').decode('utf-8') for choice in completion.choices])

import re

def escape(s):
    return re.sub(r"(?<=[ ])[\n\r](?=[a-zA-Z])", r"\\n", s)