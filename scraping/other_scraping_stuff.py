from requests import get
from requests.exceptions import RequestException
from contextlib import closing
from bs4 import BeautifulSoup
from enum import Enum
import sys
import os
import re
import csv

websiteBase = 'https://app.leg.wa.gov/RCW/default.aspx?cite='
websiteHomePage = 'https://app.leg.wa.gov/RCW/default.aspx?cite=77.15.410'
sub_alpha = '^\([a-z]+\)'
sub_numeric = '^\([0-9]+\)'
sub_roman = '^\([ivx]+\)'
current_subsection = '1'
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
        section_with_underscores = '_'.join(the_section_number.split('.'))
        condition_charge = 'Section' + section_with_underscores + '_' + current_subsection + '_'        
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
    split_index = line_to_format.find(')(')
    if split_index == 2:
        really_more = [ line_to_format[:split_index + 1], line_to_format[split_index + 1:] ]
    else:
        really_more = [ line_to_format ]
                
    global all_the_charges
    catala_code = ''
    
    # indent according to regex
    for split in really_more:
        if re.search(sub_numeric, split):
            index_of_subsection = split.find('(') + 1
            global current_subsection
            new_subsection = split[index_of_subsection]
            if current_subsection is not new_subsection:
                catala_code = format_catala(section_number)
            current_subsection = split[index_of_subsection]
            
        if re.search(sub_roman, split):
            split = '        ' + split
        elif re.search(sub_alpha, split):
            split = '    ' + split

        the_charge = get_charge(split, section_number)
        if the_charge is not None:
            all_the_charges.append(the_charge)
            
        return_string = return_string + catala_code + split + '\n'
    return return_string


with open('statutesInCSV.csv', encoding='utf-8-sig') as csvfile:
    reader = csv.reader(csvfile, delimiter=',')
    for row in reader:
        website = websiteBase + row[0]
        raw_html = simple_get(website)
        if len(raw_html) == 0:
            print('No HTML retrieved')
        else:
            all_the_text = ''
            html = BeautifulSoup(raw_html, 'html.parser')
            content = html.find('div', id='contentWrapper')
            if content is None:
                print('No content wrapper for ' + website)
                continue
            
            divs = content.find_all('div')

            # First div has RCW and section number
            rcw_number = divs[0].find('a').get_text()
            file_name = rcw_number + '.catala_en'
            if os.path.isfile('catala-regs/' + file_name):
                print('file ' + file_name + ' already exists.')
                continue            
    
            the_title = '## [' + divs[0].get_text() + ']'
            the_title = ' '.join(the_title.split())
    
            all_the_text = the_title + '\n\n'
    
            # Second div has description of section
            the_script = divs[1].get_text()
            all_the_text = all_the_text + the_script + '\n\n'
    
            # 3rd div has all the other divs
            the_text = divs[2].find_all('div')
    
            # remaining divs have text of section
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

            #print(all_the_text)
            #print(content.prettify())
            with open('test_regs/' + file_name, 'a') as f:
                f.write(all_the_text)
    