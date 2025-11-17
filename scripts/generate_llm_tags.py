import os
import yaml
import re
import sys
from google import genai
from google.genai.errors import APIError

# Nombre del campo que usaremos en el Front Matter
GENERATED_TAGS_KEY = 'llm_tags'

def get_post_content(file_path):
    """Extrae el YAML Front Matter y el contenido del post."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"ERROR: File not found at {file_path}")
        return None, None, None

    # Regex para separar el YAML del contenido (Debe estar al inicio del archivo)
    front_matter_match = re.search(r'^---\n(.*?)\n---', content, re.DOTALL | re.MULTILINE)
    
    if not front_matter_match:
        print("ERROR: Could not find valid YAML Front Matter in the file.")
        return None, None, None
    
    front_matter_str = front_matter_match.group(1)
    front_matter_data = yaml.safe_load(front_matter_str)
    # Índice donde termina el Front Matter para reconstruir el archivo
    body_start_index = front_matter_match.end()
    body_content = content[body_start_index:]
    
    return front_matter_data, body_content, body_start_index

def call_llm_for_tags(client, content):
    """Llama a la API de Gemini para generar 5 tags en inglés."""
    
    # Instrucción clave para el razonamiento, el idioma y el formato
    prompt = (
        "Analyze the following blog post content written in ENGLISH. Generate 5 high-value, "
        "niche, and recruitment-friendly technical tags (keywords) in **ENGLISH** "
        "that best summarize the topic and skills demonstrated. Return ONLY the 5 tags "
        "separated by commas, with NO other surrounding text, punctuation, or explanation."
        f"Content (first 2000 chars): {content[:2000]}"
    )
    
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash', # Modelo rápido y económico
            contents=prompt
        )
        
        # Limpieza de la respuesta para asegurar formato de lista
        tags_text = response.text.strip().replace('"', '').replace("'", '')
        
        # Dividir por coma y asegurar que no hay elementos vacíos
        tags_list = [tag.strip() for tag in tags_text.split(',') if tag.strip()]
        
        # Verificación final para asegurar que tenemos una lista de tags
        if not tags_list:
             print("Warning: LLM returned text but could not be parsed into tags.")
             return None
             
        return tags_list
        
    except APIError as e:
        print(f"ERROR: Gemini API call failed. Check API key/billing: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)
        return None

def update_post(file_path, new_tags, front_matter_data, body_start_index):
    """Reescribe el post con los nuevos tags en el Front Matter."""
    front_matter_data[GENERATED_TAGS_KEY] = new_tags
    
    # Usar yaml.dump para convertir el diccionario actualizado de nuevo a YAML
    new_front_matter_str = yaml.dump(front_matter_data, sort_keys=False)
    
    # Reconstruir el contenido del archivo
    with open(file_path, 'r', encoding='utf-8') as f:
        original_content = f.read()

    body_content = original_content[body_start_index:]
    
    new_content = f"---\n{new_front_matter_str}---\n{body_content}"
    
    # Escribir el contenido actualizado de vuelta al archivo
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)


if __name__ == '__main__':
    # Obtener las variables de entorno de GitHub Actions
    file_to_process = os.environ.get('POST_TO_PROCESS')
    api_key = os.environ.get('GEMINI_API_KEY')
    
    if not file_to_process or file_to_process == '[]':
        print("INFO: No new post to process. Exiting script gracefully.")
        sys.exit(0)
    
    if not api_key:
        print("ERROR: GEMINI_API_KEY is not set. Cannot run LLM functionality.", file=sys.stderr)
        sys.exit(1)

    print(f"--- Starting LLM Tag Generation for: {file_to_process} ---")
    
    # 1. Obtener contenido y Front Matter
    front_matter, content, body_start = get_post_content(file_to_process)
    
    if not front_matter or not content:
        sys.exit(1)

    # 2. Verificación de Ahorro de Costos
    if GENERATED_TAGS_KEY in front_matter and front_matter[GENERATED_TAGS_KEY] is not None:
        print("INFO: Post already has LLM tags. Skipping API call to save cost.")
        sys.exit(0)

    # 3. Llamar al LLM
    print("Calling Gemini API...")
    client = genai.Client(api_key=api_key)
    llm_tags = call_llm_for_tags(client, content)
    
    if llm_tags and len(llm_tags) > 0:
        # 4. Actualizar el archivo
        update_post(file_to_process, llm_tags, front_matter, body_start)
        print(f"SUCCESS: Generated and added {len(llm_tags)} tags: {llm_tags}")
        
        # Nota: El archivo modificado debe ser añadido al índice de Git si se va a commitear en un paso posterior
        # Pero, por ahora, el flujo de Jekyll lo usará localmente para la construcción.
        
    else:
        print("WARNING: LLM call failed or returned no usable tags.", file=sys.stderr)
        # No salimos con error 1 para no detener el build, pero la funcionalidad falló.
        sys.exit(0)
