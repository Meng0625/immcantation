#!/usr/bin/env python3
"""
Versioning helper script
"""
# Imports
import hglib
import re
import sys
import yaml
from argparse import ArgumentParser
from collections import OrderedDict
from subprocess import check_output, CalledProcessError, STDOUT

# Defaults
default_version_file='/Version.yaml'
default_package='immcantation'

# Set YAML loader to OrderedDict
def dict_representer(dumper, data):  return dumper.represent_dict(data.iteritems())
def dict_constructor(loader, node):  return OrderedDict(loader.construct_pairs(node))
yaml.add_representer(OrderedDict, dict_representer)
yaml.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, dict_constructor)


class Version():
    """
    Version set class
    """
    def __init__(self, versions):
        self.version = versions['immcantation']['version']
        self.date = versions['immcantation']['date']
        self.packages = {'immcantation': versions['immcantation']['version']}
        self.packages.update(versions['release'])
        self.packages.update(versions['software'])
        self.sections = OrderedDict([('release', versions['release'].keys()),
                                     ('software', versions['software'].keys())])

    def package(self, x):
        return self.packages[x]


def readVersions(version_file=default_version_file):
    """
    Read a YAML version file

    Arguments:
      version_file : YAML file containing version information.

    Returns:
      Version : Version object.
    """
    with open(version_file, 'r') as handle:
        return Version(yaml.load(handle))


def inspectVersions(version_file=default_version_file):
    """
    Determine installed package versions

    Arguments:
      version_file : YAML file containing version information.

    Returns:
      dict: version strings.
    """
    # Command line version inspection
    #
    # PRESTO=$(python3 -c "import presto; print('%s-%s' % (presto.__version__, presto.__date__))")
    # CHANGEO=$(python3 -c "import changeo; print('%s-%s' % (changeo.__version__, changeo.__date__))")
    # ALAKAZAM=$(Rscript -e "cat(packageDescription('alakazam', fields='Version'))")
    # IGBLAST=$(igblastn -version  | grep 'Package' |sed s/'Package: '//)
    # MUSCLE=$(muscle -version)
    # VSEARCH=$(vsearch --version 2> >(head -n1 | cut -d',' -f1))
    # BLAST=$(blastn -version  | grep 'Package' |sed s/'Package: '//)

    # Only available via the version file
    versions = readVersions(version_file=version_file)

    # pRESTO
    try:
        import presto
        versions.packages['presto'] = presto.__version__
    except ImportError:
        versions.packages['presto'] = None

    # Change-O
    try:
        import changeo
        versions.packages['changeo'] = changeo.__version__
    except ImportError:
        versions.packages['changeo'] = None

    # Alakazam
    try:
        alakazam = check_output('Rscript -e \"cat(packageDescription(\'alakazam\', fields=\'Version\'))\"',
                                stderr=STDOUT, shell=True)
        versions.packages['alakazam'] = re.search(r'([0-9.]+)', alakazam.decode('utf-8')).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['alakazam'] = None

    # SHazaM
    try:
        shazam = check_output('Rscript -e \"cat(packageDescription(\'shazam\', fields=\'Version\'))\"',
                              stderr=STDOUT, shell=True)
        versions.packages['shazam'] = re.search(r'([0-9.]+)', shazam.decode('utf-8')).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['shazam'] = None

    # TIgGER
    try:
        tigger = check_output('Rscript -e \"cat(packageDescription(\'tigger\', fields=\'Version\'))\"',
                              stderr=STDOUT, shell=True)
        versions.packages['tigger'] = re.search(r'([0-9.]+)', tigger.decode('utf-8')).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['tigger'] = None

    # RDI
    try:
        rdi = check_output('Rscript -e \"cat(packageDescription(\'rdi\', fields=\'Version\'))\"',
                            stderr=STDOUT, shell=True)
        versions.packages['rdi'] = re.search(r'([0-9.]+)', rdi.decode('utf-8')).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['rdi'] = None

    # SCOPer
    try:
        scoper = check_output('Rscript -e \"cat(packageDescription(\'scoper\', fields=\'Version\'))\"',
                            stderr=STDOUT, shell=True)
        versions.packages['scoper'] = re.search(r'([0-9.]+)', scoper.decode('utf-8')).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['scoper'] = None

    # prestoR
    try:
        prestor = check_output('Rscript -e \"cat(packageDescription(\'prestor\', fields=\'Version\'))\"',
                               stderr=STDOUT, shell=True)
        versions.packages['prestor'] = re.search(r'([0-9.]+)', prestor.decode('utf-8')).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['prestor'] = None

    # MUSCLE
    try:
        muscle = check_output('muscle -version', stderr=STDOUT, shell=True)
        muscle = muscle.decode('utf-8').split()[1]
        versions.packages['muscle'] = re.search(r'(?<=v)([0-9.]+)', muscle).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['muscle'] = None

    # vsearch
    try:
        vsearch = check_output('vsearch --version', stderr=STDOUT, shell=True)
        vsearch = vsearch.decode('utf-8').split('\n')[0]
        versions.packages['vsearch'] = re.search(r'(?<=v)([0-9.]+)', vsearch).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['vsearch'] = None

    # CD-HIT
    try:
        cdhit = check_output('cd-hit-est -h; exit 0', stderr=STDOUT, shell=True)
        cdhit = cdhit.decode('utf-8').split('\n')[0]
        versions.packages['cd-hit'] = re.search(r'(?<=CD-HIT version )([0-9.]+)', cdhit).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['cd-hit'] = None

    # BLAST
    try:
        blast = check_output('blastn -version', stderr=STDOUT, shell=True)
        blast = blast.decode('utf-8').split('\n')[1]
        versions.packages['blast'] = re.search(r'(?<=blast )([0-9.]+)', blast).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['blast'] = None

    # IgBLAST
    try:
        igblast = check_output('igblastn -version', stderr=STDOUT, shell=True)
        igblast = igblast.decode('utf-8').split('\n')[1]
        versions.packages['igblast'] = re.search(r'(?<=igblast )([0-9.]+)', igblast).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['igblast'] = None

    # PHYLIP
    try:
        phylip = check_output('echo "NULL" | drawtree; exit 0', stderr=STDOUT, shell=True)
        phylip = phylip.decode('utf-8').split('\n')[0]
        versions.packages['phylip'] =  re.search(r'(?<=PHYLIP version )([0-9.]+)', phylip).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['phylip'] = None

    # IgPhyML
    try:
        igphyml = check_output('igphyml -h; exit 0', stderr=STDOUT, shell=True)
        igphyml = igphyml.decode('utf-8').split('\n')[1]
        versions.packages['igphyml'] = re.search(r'(?<=IgPhyML )([0-9.]+)', igphyml).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['igphyml'] = None

    # AIRR Python library
    try:
        import airr
        versions.packages['airr-py'] = airr.__version__
    except ImportError:
        versions.packages['airr-py'] = None

    # AIRR R Library
    try:
        airr_r = check_output('Rscript -e \"cat(packageDescription(\'airr\', fields=\'Version\'))\"',
                               stderr=STDOUT, shell=True)
        versions.packages['airr-r'] = re.search(r'([0-9.]+)', airr_r.decode('utf-8')).group(0)
    except (CalledProcessError, AttributeError):
        versions.packages['airr-r'] = None

    return versions


def updateChangeset(package, repo, version_file):
    """
    Print version for package

    Arguments:
      package : name of the package to return version information for.
      repo : path to mercurial repository.
      version_file : YAML file containing version information.

    Returns:
      str: changeset updated to.
    """
    # Get version and changeset
    version = getVersion(package, version_file=version_file)
    changeset = getChangeset(version, repo=repo)

    # Update repo
    if changeset is not None:
        client = hglib.open(repo)
        client.update(changeset)

    return(changeset)


def getChangeset(version, repo):
    """
    Print version for package

    Arguments:
      version : Version string to search in tags for.
      repo : Path to mercurial repository.

    Returns:
      str: changeset.
    """
    if version is None:
        print(None)
        return None

    # Build regex
    v = re.compile(r'(^|[\svV])' + version + r'([\s-]|$)')

    # Open repo and retrieve tags
    client = hglib.open(repo)
    tags = client.tags()

    # Check for version number in tags
    changeset = None
    for x in tags:
        if v.search(x[0].decode('utf-8')):
            changeset = '%i:%s' % (x[1], x[2].decode('utf-8'))
            break
    print(changeset)

    return changeset


def getVersion(package=default_package, version_file=default_version_file):
    """
    Print version for package

    Arguments:
      package : name of the package to return version information for.
      version_file : YAML file containing version information.

    Returns:
      str: version.
    """
    v = readVersions(version_file)
    p = v.package(package)

    print(p)
    return(p)


def reportVersions(version_file=default_version_file):
    """
    Report all versions

    Arguments:
      version_file : YAML file containing version information.

    Returns:
      str : version.
    """
    versions = inspectVersions(version_file=version_file)

    report = ['immcantation: %s' % versions.version] + \
             ['date: %s' % versions.date]

    print(versions.sections.keys())
    for __, packages in versions.sections.items():
        report += [''] + ['  %s: %s' % (x, versions.package(x)) for x in packages]

    print('\n'.join(report))
    return(report)


def getArgParser():
    """
    Defines the ArgumentParser

    Returns:
     argparse.ArgumentParser : argument parser
    """
    parser = ArgumentParser()
    subparsers = parser.add_subparsers(title='subcommands', metavar='', help='Task')
    subparsers.required = True

    # Get build file version
    parser_get = subparsers.add_parser('get',
                                       help='Retrieve version number from version file.',
                                       description='Retrieve version number from version file.')
    parser_get.add_argument('-n', action='store', dest='package', type=str, required=True,
                            help='Package name.')
    parser_get.add_argument('-f', action='store', dest='version_file', type=str,
                            default=default_version_file, help='YAML version file.')
    parser_get.set_defaults(main=getVersion)

    # Get mercurial changeset
    parser_cset = subparsers.add_parser('changeset',
                                        help='Retrieve changeset for a tagged version from a mercurial repository.',
                                        description='Retrieve changeset for a tagged version from a mercurial repository.')
    parser_cset.add_argument('-v', action='store', dest='version', type=str, required=True,
                             help='Version number.')
    parser_cset.add_argument('-r', action='store', dest='repo', type=str, required=True,
                             help='Path to the mercurial repository.')
    parser_cset.set_defaults(main=getChangeset)

    # Update mercurial changeset
    parser_update = subparsers.add_parser('update',
                                          help='Update a mercurial repository to tagged version number from version file.',
                                          description='Update a mercurial repository to tagged version number from version file.')
    parser_update.add_argument('-n', action='store', dest='package', type=str, required=True,
                               help='Package name.')
    parser_update.add_argument('-r', action='store', dest='repo', type=str, required=True,
                               help='Path to the mercurial repository.')
    parser_update.add_argument('-f', action='store', dest='version_file', type=str,
                               default=default_version_file, help='YAML version file.')
    parser_update.set_defaults(main=updateChangeset)

    # Inspect installed applications
    parser_report = subparsers.add_parser('report',
                                          help='Retrieve version information from installed packages.',
                                          description='Retrieve version information from installed packages.')
    parser_report.add_argument('-f', action='store', dest='version_file', type=str,
                               default=default_version_file, help='YAML version file.')
    parser_report.set_defaults(main=reportVersions)

    return(parser)


if __name__ == '__main__':
    """
    Parses command line arguments and calls main function
    """
    parser = getArgParser()
    args = parser.parse_args()

    main = args.main
    args_dict = args.__dict__
    del args_dict['main']

    check = main(**args_dict)
    if check is None:  sys.exit(1)