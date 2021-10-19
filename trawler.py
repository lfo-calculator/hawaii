from requests import get
from requests.exceptions import RequestException
from contextlib import closing
from bs4 import BeautifulSoup
from enum import Enum
import time
import sys
import os
import re
import csv

home_page = 'https://app.leg.wa.gov/RCW/default.aspx'
cite_website = 'https://app.leg.wa.gov/RCW/default.aspx?cite='
base_website = 'https://app.leg.wa.gov/RCW/'
sub_alpha = '^\([a-z]+\)'
sub_numeric = '^\([0-9]+\)'
sub_roman = '^\([ivx]+\)'
current_subsection = ''
current_subsubsection = ''
current_subsubsubsection = ''
all_the_charges = []

def simple_get(url):
    try:
        with closing(get(url, stream=True)) as resp:
            if is_good_response(resp):
                return resp.content
            else:
                return None

    except RequestException as e:
        log_error('Error during requests to {0} : {1}'.format(url, str(e)))
        return None

    
def is_good_response(resp):
    content_type = resp.headers['Content-Type'].lower()
    return (resp.status_code == 200
            and content_type is not None
            and content_type.find('html') > -1)


def log_error(e):
    print('My Error:', e, time.strftime(('%X %x %Z')))


def get_charge(line_to_check, the_section_number):
    charge = ''
    if line_to_check.find('class A felony') > -1:
        charge = 'FelonyA'
    elif line_to_check.find('class B felony') > -1:
        charge = 'FelonyB'
    elif line_to_check.find('class C felony') > -1:
        charge = 'FelonyC'
    elif line_to_check.find('felony') > -1:
        # possible general list - no charges
        charge = ''
    elif line_to_check.find('gross misdemeanor') > -1:
        charge = 'GrossMisdemeanor'
    elif line_to_check.find('misdemeanor') > -1:
        charge = 'SimpleMisdemeanor'

    if len(charge) > 0:
        global current_subsection
        global current_subsubsection
        global current_subsubsubsection
        section_with_underscores = '_'.join(the_section_number.split('.'))
        condition_charge = 'Section' + section_with_underscores + '_' + current_subsection + '_'
        if current_subsubsection != '':
            condition_charge = condition_charge + current_subsubsection + '_'
            if current_subsubsubsection != '':
                condition_charge = condition_charge + current_subsubsubsection + '_'
        return '  definition class\n  under condition charge = ' + condition_charge + '\n  consequence equals ' + charge + '\n'
    else:
        return None


def format_catala(the_section_number):
    global all_the_charges
    if len(all_the_charges) == 0:
        return ''
    
    return_block = '\n```catala\nscope RCW_' + '_'.join(the_section_number.split('.')) + ':'
    number_of_charges = len(all_the_charges)

    for i in range(number_of_charges):
        return_block = return_block + '\n' + all_the_charges[i]

    return_block = return_block + '```\n\n'
    all_the_charges.clear()
    return return_block
    
    
def format_the_line(line_to_format, section_number):
    return_string = ''
    global current_subsection
    global current_subsubsection
    global current_subsubsubsection
    split_index = line_to_format.find(')(')
    if split_index == 2:
        really_more = [ line_to_format[:split_index + 1], line_to_format[split_index + 1:] ]
    else:
        really_more = [ line_to_format ]
                
    global all_the_charges
    catala_code = ''
    
    # indent according to regex
    for split in really_more:
        split = ' '.join(split.split())
        numeric_re = re.search(sub_numeric, split)
        roman_re = re.search(sub_roman, split)
        alpha_re = re.search(sub_alpha, split)

        if numeric_re:
            current_subsection = numeric_re.group()[1:-1]
            current_subsubsection = ''
            current_subsubsubsection = ''  
        elif roman_re and current_subsubsection != 'h':
            current_subsubsubsection = roman_re.group()[1:-1]
            split = '        ' + split
        elif alpha_re:
            current_subsubsection = alpha_re.group()[1:-1]
            current_subsubsubsection = ''
            split = '    ' + split

        the_charge = get_charge(split, section_number)
        if the_charge is not None:
            all_the_charges.append(the_charge)
            
        return_string = return_string + catala_code + split + '\n'
    return return_string


def parse_section_text(content_wrapper):
    global current_subsection
    global current_subsubsection
    global current_subsubsubsection
    current_subsection = ''
    current_subsubsection = ''
    current_subsubsubsection = ''
    
    all_the_text = 'auto-generated file: remove this line once reviewed by peoples\n'            
    divs = content_wrapper.find_all('div')

    # First div has RCW and section number
    rcw_number = divs[0].find('a').get_text()
    file_name = rcw_number + '.catala_en'
    if os.path.isfile('catala-regs/' + file_name):
        print('file ' + file_name + ' already exists.')
        return            

    the_title = divs[0].get_text() + ' ' + divs[1].get_text()
    the_title = ' '.join(the_title.split())
    line_1 = '## ' + the_title
    line_2 = '## [' + the_title + ']'
    all_the_text = all_the_text + line_1 + '\n\n'

    # since we're here, we know (maybe) that this will return a class for a charge
    all_the_text = all_the_text + '> Begin metadata\n\n```catala\n\n  # Inputs:\n  context charge content Charge\n\n  # Output\n  context class content Class\n```\n\n> End metadata\n\n' + line_2 + '\n\n'

    # 3rd div has all the other divs with the text
    the_text = divs[2].find_all('div')

    if divs[1].get_text().find('(Effective') > -1:
        # then there are potentially 2 blurbs
        for i in range(2, len(divs)):
            if divs[i].get_text().find('(Effective') > -1:
                the_text.extend(divs[i + 1].find_all('div'))
                break

    for i in range(0, len(the_text)):
        skippable = False
        possible_table = the_text[i].find_all('tr')
        if len(possible_table) > 0:
            for j in range(0, len(possible_table)):
                row_text = possible_table[j].get_text(' ', strip=True)
                formatted_line = format_the_line(row_text, rcw_number)
                all_the_text = all_the_text + formatted_line
        else:
            # Check if parent is a tr
            for parent in the_text[i].parents:
                if parent.name == 'tr':
                    skippable = True
                    break
                if parent.id == 'contentWrapper':
                    break
            if skippable is not True:
                the_line = the_text[i].get_text()
                formatted_line = format_the_line(the_line, rcw_number)
                all_the_text = all_the_text + formatted_line

    all_the_text = all_the_text + format_catala(rcw_number)

    #print(all_the_text)
    #print(content.prettify())
    with open('test-regs/' + file_name, 'w') as f:
        f.write(all_the_text)


# start small
keywords = ['class A felony', 'class B felony', 'class C felony', 'gross misdemeanor', 'misdemeanor']

with open('test-regs/section_list.txt', 'a') as file:
    title_website = 'https://app.leg.wa.gov/RCW/default.aspx?cite=46'
    title_raw_html = simple_get(title_website)
    title_html = BeautifulSoup(title_raw_html, 'html.parser')
    chapter_headings = title_html.find_all('tr')[2:]
    for chapter_tr in chapter_headings:
        time.sleep(3)
        chapter_website = chapter_tr.find('a').get('href')
        chapter_raw_html = simple_get(chapter_website)
        chapter_html = BeautifulSoup(chapter_raw_html, 'html.parser')
        section_headings = chapter_html.find_all('tr')
        for section_tr in section_headings:
            time.sleep(3)
            section_a = section_tr.find('a')
            if section_a is None:
                continue
            section_website = section_a.get('href')
            #section_website = 'http://app.leg.wa.gov/RCW/default.aspx?cite=46.10.505'
            section_raw_html = simple_get(section_website)
            section_html = BeautifulSoup(section_raw_html, 'html.parser')

            # here we start looking for keywords - start with content wrapper
            content = section_html.find('div', id='contentWrapper')
            if content is None:
                print('No content for ' + section_website)
                continue

            # gets all the text in the content wrapper then search for keywords
            all_the_text = content.get_text()
            #keyword_to_search_for = 'violation of this title'
            for keyword_to_search_for in keywords:
                if all_the_text.find(keyword_to_search_for) > -1:
                    file.write(section_website + '\n')
                    parse_section_text(content)
                    break
